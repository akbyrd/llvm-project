//===- ControlFlowToSCF.h - ControlFlow to SCF -------------*- C++ ------*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Define conversions from the ControlFlow dialect to the SCF dialect.
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/ControlFlowToSCF/ControlFlowToSCF.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlow.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlowOps.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/Dialect/UB/IR/UBOps.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/CFGToSCF.h"

namespace mlir {
#define GEN_PASS_DEF_LIFTCONTROLFLOWTOSCFPASS
#include "mlir/Conversion/Passes.h.inc"
} // namespace mlir

using namespace mlir;

namespace {

class ControlFlowToSCFTransformation : public CFGToSCFInterface {
public:
  FailureOr<Operation *> createStructuredBranchRegionOp(
      OpBuilder &builder, Operation *controlFlowCondOp, TypeRange resultTypes,
      MutableArrayRef<Region> regions) override {
    if (auto condBrOp = dyn_cast<cf::CondBranchOp>(controlFlowCondOp)) {
      assert(regions.size() == 2);
      auto ifOp = builder.create<scf::IfOp>(
          controlFlowCondOp->getLoc(), resultTypes, condBrOp.getCondition());
      ifOp.getThenRegion().takeBody(regions[0]);
      ifOp.getElseRegion().takeBody(regions[1]);
      return ifOp.getOperation();
    }

    if (auto switchOp = dyn_cast<cf::SwitchOp>(controlFlowCondOp)) {
      // `getCFGSwitchValue` returns an i32 that we need to convert to index
      // fist.
      auto cast = builder.create<arith::IndexCastUIOp>(
          controlFlowCondOp->getLoc(), builder.getIndexType(),
          switchOp.getFlag());
      SmallVector<int64_t> cases;
      if (auto caseValues = switchOp.getCaseValues())
        llvm::append_range(
            cases, llvm::map_range(*caseValues, [](const llvm::APInt &apInt) {
              return apInt.getZExtValue();
            }));

      assert(regions.size() == cases.size() + 1);

      auto indexSwitchOp = builder.create<scf::IndexSwitchOp>(
          controlFlowCondOp->getLoc(), resultTypes, cast, cases, cases.size());

      indexSwitchOp.getDefaultRegion().takeBody(regions[0]);
      for (auto &&[targetRegion, sourceRegion] :
           llvm::zip(indexSwitchOp.getCaseRegions(), llvm::drop_begin(regions)))
        targetRegion.takeBody(sourceRegion);

      return indexSwitchOp.getOperation();
    }

    controlFlowCondOp->emitOpError(
        "Cannot convert unknown control flow op to structured control flow");
    return failure();
  }

  LogicalResult
  createStructuredBranchRegionTerminatorOp(Location loc, OpBuilder &builder,
                                           Operation *branchRegionOp,
                                           ValueRange results) override {
    builder.create<scf::YieldOp>(loc, results);
    return success();
  }

  FailureOr<Operation *>
  createStructuredDoWhileLoopOp(OpBuilder &builder, Operation *replacedOp,
                                ValueRange loopVariablesInit, Value condition,
                                ValueRange loopVariablesNextIter,
                                Region &&loopBody) override {
    Location loc = replacedOp->getLoc();
    auto whileOp = builder.create<scf::WhileOp>(
        loc, loopVariablesInit.getTypes(), loopVariablesInit);

    whileOp.getBefore().takeBody(loopBody);

    builder.setInsertionPointToEnd(&whileOp.getBefore().back());
    // `getCFGSwitchValue` returns a i32. We therefore need to truncate the
    // condition to i1 first. It is guaranteed to be either 0 or 1 already.
    builder.create<scf::ConditionOp>(
        loc,
        builder.create<arith::TruncIOp>(loc, builder.getI1Type(), condition),
        loopVariablesNextIter);

    auto *afterBlock = new Block;
    whileOp.getAfter().push_back(afterBlock);
    afterBlock->addArguments(
        loopVariablesInit.getTypes(),
        SmallVector<Location>(loopVariablesInit.size(), loc));
    builder.setInsertionPointToEnd(afterBlock);
    builder.create<scf::YieldOp>(loc, afterBlock->getArguments());

    return whileOp.getOperation();
  }

  Value getCFGSwitchValue(Location loc, OpBuilder &builder,
                          unsigned int value) override {
    return builder.create<arith::ConstantOp>(loc,
                                             builder.getI32IntegerAttr(value));
  }

  void createCFGSwitchOp(Location loc, OpBuilder &builder, Value flag,
                         ArrayRef<unsigned int> caseValues,
                         BlockRange caseDestinations,
                         ArrayRef<ValueRange> caseArguments, Block *defaultDest,
                         ValueRange defaultArgs) override {
    builder.create<cf::SwitchOp>(loc, flag, defaultDest, defaultArgs,
                                 llvm::to_vector_of<int32_t>(caseValues),
                                 caseDestinations, caseArguments);
  }

  Value getUndefValue(Location loc, OpBuilder &builder, Type type) override {
    return builder.create<ub::PoisonOp>(loc, type, nullptr);
  }

  FailureOr<Operation *> createUnreachableTerminator(Location loc,
                                                     OpBuilder &builder,
                                                     Region &region) override {

    // TODO: This should create a `ub.unreachable` op. Once such an operation
    //       exists to make the pass can be made independent of the func
    //       dialect. For now just return poison values.
    auto funcOp = dyn_cast<func::FuncOp>(region.getParentOp());
    if (!funcOp)
      return emitError(loc, "Expected '")
             << func::FuncOp::getOperationName() << "' as top level operation";

    return builder
        .create<func::ReturnOp>(
            loc, llvm::map_to_vector(funcOp.getResultTypes(),
                                     [&](Type type) {
                                       return getUndefValue(loc, builder, type);
                                     }))
        .getOperation();
  }
};

struct LiftControlFlowToSCF
    : public impl::LiftControlFlowToSCFPassBase<LiftControlFlowToSCF> {

  using Base::Base;

  void runOnOperation() override {
    ControlFlowToSCFTransformation transformation;

    bool changed = false;
    WalkResult result = getOperation()->walk([&](func::FuncOp funcOp) {
      if (funcOp.getBody().empty())
        return WalkResult::advance();

      FailureOr<bool> changedFunc = transformCFGToSCF(
          funcOp.getBody(), transformation,
          funcOp != getOperation() ? getChildAnalysis<DominanceInfo>(funcOp)
                                   : getAnalysis<DominanceInfo>());
      if (failed(changedFunc))
        return WalkResult::interrupt();

      changed |= *changedFunc;
      return WalkResult::advance();
    });
    if (result.wasInterrupted())
      return signalPassFailure();

    if (!changed)
      markAllAnalysesPreserved();
  }
};
} // namespace
