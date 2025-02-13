// RUN: mlir-opt --convert-nvvm-to-llvm --convert-arith-to-llvm --split-input-file %s | FileCheck %s

// Same below, but using the `ConvertToLLVMPatternInterface` entry point
// and the generic `convert-to-llvm` pass.
// RUN: mlir-opt --convert-to-llvm --split-input-file %s | FileCheck %s

// CHECK-LABEL : @init_mbarrier_arrive_expect_tx
llvm.func @init_mbarrier_arrive_expect_tx(%barrier : !llvm.ptr<3>, %txcount : i32) {
  //CHECK : llvm.inline_asm has_side_effects asm_dialect = att "mbarrier.arrive.expect_tx.shared.b64 _, [$0], $1;", "r,r" 
  nvvm.mbarrier.arrive.expect_tx.shared %barrier, %txcount : !llvm.ptr<3>, i32
  llvm.return
}

// CHECK-LABEL : @init_mbarrier_arrive_expect_tx_generic
llvm.func @init_mbarrier_arrive_expect_tx_generic(%barrier : !llvm.ptr, %txcount : i32) {
  // CHECK: llvm.inline_asm has_side_effects asm_dialect = att "mbarrier.arrive.expect_tx.b64 _, [$0], $1;", "l,r" 
  nvvm.mbarrier.arrive.expect_tx %barrier, %txcount : !llvm.ptr, i32
  llvm.return
}

// CHECK-LABEL : @init_mbarrier_try_wait.parity.shared
llvm.func @init_mbarrier_try_wait_shared(%barrier : !llvm.ptr<3>, %ticks : i32, %phase : i32) {
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "{\0A\09.reg .pred       P1; \0A\09LAB_WAIT: \0A\09mbarrier.try_wait.parity.shared.b64 P1, [$0], $1, $2; \0A\09@P1 bra.uni DONE; \0A\09bra.uni     LAB_WAIT; \0A\09DONE: \0A\09}", "r,r,r"
   nvvm.mbarrier.try_wait.parity.shared %barrier, %phase, %ticks : !llvm.ptr<3>, i32, i32
  llvm.return
}

// CHECK-LABEL : @init_mbarrier_try_wait.parity
llvm.func @init_mbarrier_try_wait(%barrier : !llvm.ptr, %ticks : i32, %phase : i32){
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "{\0A\09.reg .pred       P1; \0A\09LAB_WAIT: \0A\09mbarrier.try_wait.parity.b64 P1, [$0], $1, $2; \0A\09@P1 bra.uni DONE; \0A\09bra.uni     LAB_WAIT; \0A\09DONE: \0A\09}", "r,r,r"
  nvvm.mbarrier.try_wait.parity %barrier, %phase, %ticks : !llvm.ptr, i32, i32
  llvm.return
}

// CHECK-LABEL : @async_cp
func.func @async_cp(%dst: !llvm.ptr<3>, %src: !llvm.ptr<1>) {
  // CHECK : nvvm.cp.async.shared.global %{{.*}}, %{{.*}}, 16, cache =  ca : !llvm.ptr<3>, !llvm.ptr<1>
  nvvm.cp.async.shared.global %dst, %src, 16, cache =  ca : !llvm.ptr<3>, !llvm.ptr<1>
  // CHECK : nvvm.cp.async.shared.global %{{.*}}, %{{.*}}, 16, cache =  cg : !llvm.ptr<3>, !llvm.ptr<1>
  nvvm.cp.async.shared.global %dst, %src, 16, cache =  cg : !llvm.ptr<3>, !llvm.ptr<1>
  return
}

// CHECK-LABEL : @async_cp_zfill
func.func @async_cp_zfill(%dst: !llvm.ptr<3>, %src: !llvm.ptr<1>, %cpSize: i32) {
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "cp.async.cg.shared.global [$0], [$1], $2, $3;\0A", "r,l,r" %{{.*}}, %{{.*}}, %{{.*}} : (!llvm.ptr<3>, !llvm.ptr<1>, i32) -> !llvm.void
  nvvm.cp.async.shared.global %dst, %src, 16, cache =  cg, %cpSize : !llvm.ptr<3>, !llvm.ptr<1>, i32
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "cp.async.ca.shared.global [$0], [$1], $2, $3;\0A", "r,l,r" %{{.*}}, %{{.*}}, %{{.*}} : (!llvm.ptr<3>, !llvm.ptr<1>, i32) -> !llvm.void
  nvvm.cp.async.shared.global %dst, %src, 4, cache =  ca, %cpSize : !llvm.ptr<3>, !llvm.ptr<1>, i32
  return
}

// CHECK-LABEL : @tma_load_1d
func.func @tma_load_1d(%tmaDescriptor: !llvm.ptr, %dest : !llvm.ptr<3>, %barrier: !llvm.ptr<3>, %crd0: i32) {
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "cp.async.bulk.tensor.1d.shared::cluster.global.mbarrier::complete_tx::bytes [$0], [$1, {$3}], [$2];", "l,r,r,r"
  nvvm.cp.async.bulk.tensor.shared.cluster.global %dest, %tmaDescriptor,  %barrier, box[%crd0] : !llvm.ptr<3>, !llvm.ptr, !llvm.ptr<3>, i32
  return
}

// CHECK-LABEL : @tma_load_2d
func.func @tma_load_2d(%tmaDescriptor: !llvm.ptr, %dest : !llvm.ptr<3>, %barrier: !llvm.ptr<3>, %crd0: i32, %crd1: i32) {
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes [$0], [$1, {$3, $4}], [$2];", "l,r,r,r,r"
  nvvm.cp.async.bulk.tensor.shared.cluster.global %dest, %tmaDescriptor,  %barrier, box[%crd0,%crd1] : !llvm.ptr<3>, !llvm.ptr, !llvm.ptr<3>, i32, i32
  return
}

// CHECK-LABEL : @tma_load_3d
func.func @tma_load_3d(%tmaDescriptor: !llvm.ptr, %dest : !llvm.ptr<3>, %barrier: !llvm.ptr<3>, %crd0: i32, %crd1: i32, %crd2: i32) {
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "cp.async.bulk.tensor.3d.shared::cluster.global.mbarrier::complete_tx::bytes [$0], [$1, {$3, $4, $5}], [$2];", "l,r,r,r,r,r"
  nvvm.cp.async.bulk.tensor.shared.cluster.global %dest, %tmaDescriptor,  %barrier, box[%crd0,%crd1,%crd2] : !llvm.ptr<3>, !llvm.ptr, !llvm.ptr<3>, i32, i32, i32
  return
}

// CHECK-LABEL : @tma_load_4d
func.func @tma_load_4d(%tmaDescriptor: !llvm.ptr, %dest : !llvm.ptr<3>, %barrier: !llvm.ptr<3>, %crd0: i32, %crd1: i32, %crd2: i32, %crd3: i32) {
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "cp.async.bulk.tensor.4d.shared::cluster.global.mbarrier::complete_tx::bytes [$0], [$1, {$3, $4, $5, $6}], [$2];", "l,r,r,r,r,r,r"
  nvvm.cp.async.bulk.tensor.shared.cluster.global %dest, %tmaDescriptor,  %barrier, box[%crd0,%crd1,%crd2,%crd3] : !llvm.ptr<3>, !llvm.ptr, !llvm.ptr<3>, i32, i32, i32, i32
  return
}

// CHECK-LABEL : @tma_load_5d
func.func @tma_load_5d(%tmaDescriptor: !llvm.ptr, %dest : !llvm.ptr<3>, %barrier: !llvm.ptr<3>, %crd0: i32, %crd1: i32, %crd2: i32, %crd3: i32, %crd4: i32) {
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "cp.async.bulk.tensor.5d.shared::cluster.global.mbarrier::complete_tx::bytes [$0], [$1, {$3, $4, $5, $6, $7}], [$2];", "l,r,r,r,r,r,r,r"
  nvvm.cp.async.bulk.tensor.shared.cluster.global %dest, %tmaDescriptor,  %barrier, box[%crd0,%crd1,%crd2,%crd3,%crd4] : !llvm.ptr<3>, !llvm.ptr, !llvm.ptr<3>, i32, i32, i32, i32, i32
  return
}


// CHECK-LABEL : @wgmma_execute
func.func @wgmma_execute() {  
  nvvm.wgmma.fence.aligned
  nvvm.wgmma.commit.group.sync.aligned
  nvvm.wgmma.wait.group.sync.aligned 0
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "wgmma.fence.sync.aligned;", ""
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "wgmma.commit_group.sync.aligned;", ""
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "wgmma.wait_group.sync.aligned %0;", "n" %{{.*}} : (i32)
  

  nvvm.wgmma.fence.aligned
  nvvm.wgmma.commit.group.sync.aligned
  nvvm.wgmma.wait.group.sync.aligned 1
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "wgmma.fence.sync.aligned;", ""
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "wgmma.commit_group.sync.aligned;", ""
  // CHECK : llvm.inline_asm has_side_effects asm_dialect = att "wgmma.wait_group.sync.aligned %0;", "n" %{{.*}} : (i32)
  return
}

// -----

!mat64f32 = !llvm.struct<(
  f32, f32, f32, f32, f32, f32, f32, f32, 
  f32, f32, f32, f32, f32, f32, f32, f32)>

// CHECK-LABEL: @wgmma_f32_f16_f16(
// CHECK-SAME: %[[ARG0:.+]]: i64, %[[ARG1:.+]]: i64
func.func @wgmma_f32_f16_f16(%descA : i64, %descB : i64) -> !mat64f32{  
  // CHECK: %[[RES:.*]] = llvm.mlir.undef : !llvm.struct
  // CHECK: %[[A1:.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK: %[[A2:.*]] = llvm.mlir.constant(-1 : i32) : i32
  // CHECK: %[[A3:.*]] = llvm.mlir.constant(-1 : i32) : i32
  // CHECK: %[[A4:.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK: %[[A5:.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK: %[[V0:.*]] = llvm.extractvalue %[[RES]][0] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)> 
  // CHECK: %[[V4:.*]] = llvm.extractvalue %[[RES]][4] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)> 
  // CHECK: %[[V11:.*]] = llvm.extractvalue %[[RES]][11] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)>  
  // CHECK: %[[V13:.*]] = llvm.extractvalue %[[RES]][13] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)> 
  // CHECK: %[[RES1:.+]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $18, 0;\0Awgmma.mma_async.sync.aligned.m64n32k16.f32.f16.f16 {$0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15}, $16, $17, p, $19,  $20, $21,  $22;\0A}\0A", "=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,l,l,n,n,n,n,n" %[[V0]], %{{.*}}, %{{.*}}, %{{.*}}, %[[V4]], %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}, %[[V11]], %{{.*}}, %[[V13]], %{{.*}}, %{{.*}}, %[[ARG0]], %[[ARG1]], %[[A1]], %[[A2]], %[[A3]], %[[A4]], %[[A5]] : (f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, i64, i64, i32, i32, i32, i32, i32) -> !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)>
  // CHECK: %[[C2:.*]] = llvm.mlir.constant(2 : i64) : i64
  // CHECK: %[[DESCa:.+]] = llvm.add %[[ARG0]], %[[C2]] : i64
  // CHECK: %[[DESCb:.+]] = llvm.add %[[ARG1]], %[[C2]] : i64
  // CHECK: %[[V0_2:.*]] = llvm.extractvalue %[[RES1]][0] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)> 
  // CHECK: %[[V4_2:.*]] = llvm.extractvalue %[[RES1]][4] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)> 
  // CHECK: %[[V11_2:.*]] = llvm.extractvalue %[[RES1]][11] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)>  
  // CHECK: %[[V13_2:.*]] = llvm.extractvalue %[[RES1]][13] : !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)> 
  // CHECK: %[[RES_2:.+]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $18, 0;\0Awgmma.mma_async.sync.aligned.m64n32k16.f32.f16.f16 {$0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15}, $16, $17, p, $19,  $20, $21,  $22;\0A}\0A", "=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,l,l,n,n,n,n,n" %[[V0_2]], %{{.*}}, %{{.*}}, %{{.*}}, %[[V4_2]], %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}, %[[V11_2]], %{{.*}}, %[[V13_2]], %{{.*}}, %{{.*}}, %[[DESCa]], %[[DESCb]], %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}} : (f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, i64, i64, i32, i32, i32, i32, i32) -> !llvm.struct<(f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32)>
  %result = llvm.mlir.undef : !mat64f32
  %result1 = nvvm.wgmma.mma_async 
      %descA, %descB, 
      #nvvm.shape<m = 64, n = 32, k = 16>, 
      D [%result, #nvvm.wgmma_scale_out<zero>],
      A [<f16>, #nvvm.wgmma_scale_in<neg>, <col>], 
      B [<f16>, #nvvm.wgmma_scale_in<neg>, <col>]
      :!mat64f32 -> !mat64f32
  %c2 = arith.constant 2 : i64
  %descAnext = arith.addi %descA, %c2 : i64
  %descBnext = arith.addi %descB, %c2 : i64
  %result2 = nvvm.wgmma.mma_async 
      %descAnext, %descBnext, 
      #nvvm.shape<m = 64, n = 32, k = 16>, 
      D [%result1, #nvvm.wgmma_scale_out<zero>],
      A [<f16>, #nvvm.wgmma_scale_in<neg>, <col>], 
      B [<f16>, #nvvm.wgmma_scale_in<neg>, <col>]
      : !mat64f32 -> !mat64f32
  return %result2 : !mat64f32
}

// -----

!mat16i32 = !llvm.struct<(i32, i32, i32, i32)>

// CHECK-LABEL: @wgmma_s32_s8_s8_satfinite(
// CHECK-SAME: %[[ARG0:.+]]: i64, %[[ARG1:.+]]: i64
func.func @wgmma_s32_s8_s8_satfinite(%descA : i64, %descB : i64) -> !mat16i32{  
  %result = llvm.mlir.undef : !mat16i32
// CHECK: %[[RES:.*]] = llvm.mlir.undef : !llvm.struct
// CHECK: %[[A1:.*]] = llvm.mlir.constant(1 : i32) : i32
// CHECK: %[[V0:.*]] = llvm.extractvalue %[[RES]][0]
// CHECK: %[[V1:.*]] = llvm.extractvalue %[[RES]][1]
// CHECK: %[[V2:.*]] = llvm.extractvalue %[[RES]][2]
// CHECK: %[[V3:.*]] = llvm.extractvalue %[[RES]][3]
// CHECK: %[[RES_2:.*]] =  llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $6, 0;\0Awgmma.mma_async.sync.aligned.m64n8k32.s32.s8.s8.satfinite {$0, $1, $2, $3}, $4, $5, p;\0A}\0A", "=r,=r,=r,=r,0,1,2,3,l,l,n" %[[V0]], %[[V1]], %[[V2]], %[[V3]], %[[ARG0]], %[[ARG1]], %[[A1]] : (i32, i32, i32, i32, i64, i64, i32) -> !llvm.struct<(i32, i32, i32, i32)>
// CHECK: %[[V0_2:.*]] = llvm.extractvalue %[[RES_2]][0]
// CHECK: %[[V1_2:.*]] = llvm.extractvalue %[[RES_2]][1]
// CHECK: %[[V2_2:.*]] = llvm.extractvalue %[[RES_2]][2]
// CHECK: %[[V3_2:.*]] = llvm.extractvalue %[[RES_2]][3]
// CHECK: %[[RES_3:.*]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $6, 0;\0Awgmma.mma_async.sync.aligned.m64n8k32.s32.s8.s8.satfinite {$0, $1, $2, $3}, $4, $5, p;\0A}\0A", "=r,=r,=r,=r,0,1,2,3,l,l,n" %[[V0_2]], %[[V1_2]], %[[V2_2]], %[[V3_2]], %[[ARG0]], %[[ARG1]], %{{.*}}
// CHECK: %[[V0_3:.*]] = llvm.extractvalue %[[RES_3]][0]
// CHECK: %[[V1_3:.*]] = llvm.extractvalue %[[RES_3]][1]
// CHECK: %[[V2_3:.*]] = llvm.extractvalue %[[RES_3]][2]
// CHECK: %[[V3_3:.*]] = llvm.extractvalue %[[RES_3]][3]
// CHECK: %[[RES1:.*]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $6, 0;\0Awgmma.mma_async.sync.aligned.m64n8k32.s32.s8.s8.satfinite {$0, $1, $2, $3}, $4, $5, p;\0A}\0A", "=r,=r,=r,=r,0,1,2,3,l,l,n" %[[V0_3]], %[[V1_3]], %[[V2_3]], %[[V3_3]], %[[ARG0]], %[[ARG1]], %{{.*}} 
  %result1 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 8, k = 32>, 
      D [%result, #nvvm.wgmma_scale_out<one>, <satfinite>],
      A [<s8>, #nvvm.wgmma_scale_in<one>, <row>], 
      B [<s8>, #nvvm.wgmma_scale_in<one>, <row>]
      : !mat16i32 -> !mat16i32
  %result2 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 8, k = 32>, 
      D [%result1, #nvvm.wgmma_scale_out<one>, <satfinite>],
      A [<s8>, #nvvm.wgmma_scale_in<one>, <row>], 
      B [<s8>, #nvvm.wgmma_scale_in<one>, <row>]
      : !mat16i32 -> !mat16i32
  %result3 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 8, k = 32>, 
      D [%result2, #nvvm.wgmma_scale_out<one>, <satfinite>],
      A [<s8>, #nvvm.wgmma_scale_in<one>, <row>], 
      B [<s8>, #nvvm.wgmma_scale_in<one>, <row>]
      : !mat16i32 -> !mat16i32
  return %result3 : !mat16i32
}

// CHECK-LABEL: @wgmma_s32_u8_u8(
  // CHECK-SAME: %[[ARG0:.+]]: i64, %[[ARG1:.+]]: i64
func.func @wgmma_s32_u8_u8(%descA : i64, %descB : i64) -> !mat16i32 {  
// CHECK: %[[RES:.*]] = llvm.mlir.undef : !llvm.struct
// CHECK: %[[A1:.*]] = llvm.mlir.constant(1 : i32) : i32
// CHECK: %[[V0:.*]] = llvm.extractvalue %[[RES]][0]
// CHECK: %[[V1:.*]] = llvm.extractvalue %[[RES]][1]
// CHECK: %[[V2:.*]] = llvm.extractvalue %[[RES]][2]
// CHECK: %[[V3:.*]] = llvm.extractvalue %[[RES]][3]
// CHECK: %[[RES_2:.*]] =  llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $6, 0;\0Awgmma.mma_async.sync.aligned.m64n8k32.s32.u8.u8 {$0, $1, $2, $3}, $4, $5, p;\0A}\0A", "=r,=r,=r,=r,0,1,2,3,l,l,n" %[[V0]], %[[V1]], %[[V2]], %[[V3]], %[[ARG0]], %[[ARG1]], %[[A1]] : (i32, i32, i32, i32, i64, i64, i32) -> !llvm.struct<(i32, i32, i32, i32)>
// CHECK: %[[V0_2:.*]] = llvm.extractvalue %[[RES_2]][0]
// CHECK: %[[V1_2:.*]] = llvm.extractvalue %[[RES_2]][1]
// CHECK: %[[V2_2:.*]] = llvm.extractvalue %[[RES_2]][2]
// CHECK: %[[V3_2:.*]] = llvm.extractvalue %[[RES_2]][3]
// CHECK: %[[RES_3:.*]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $6, 0;\0Awgmma.mma_async.sync.aligned.m64n8k32.s32.u8.u8 {$0, $1, $2, $3}, $4, $5, p;\0A}\0A", "=r,=r,=r,=r,0,1,2,3,l,l,n" %[[V0_2]], %[[V1_2]], %[[V2_2]], %[[V3_2]], %[[ARG0]], %[[ARG1]], %{{.*}}
// CHECK: %[[V0_3:.*]] = llvm.extractvalue %[[RES_3]][0]
// CHECK: %[[V1_3:.*]] = llvm.extractvalue %[[RES_3]][1]
// CHECK: %[[V2_3:.*]] = llvm.extractvalue %[[RES_3]][2]
// CHECK: %[[V3_3:.*]] = llvm.extractvalue %[[RES_3]][3]
// CHECK: %[[RES1:.*]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $6, 0;\0Awgmma.mma_async.sync.aligned.m64n8k32.s32.u8.u8 {$0, $1, $2, $3}, $4, $5, p;\0A}\0A", "=r,=r,=r,=r,0,1,2,3,l,l,n" %[[V0_3]], %[[V1_3]], %[[V2_3]], %[[V3_3]], %[[ARG0]], %[[ARG1]], %{{.*}} 
  %result = llvm.mlir.undef : !mat16i32
  %result1 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 8, k = 32>, 
      D [%result, #nvvm.wgmma_scale_out<one>],
      A [<u8>, #nvvm.wgmma_scale_in<one>, <row>], 
      B [<u8>, #nvvm.wgmma_scale_in<one>, <row>]
      : !mat16i32 -> !mat16i32
  %result2 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 8, k = 32>, 
      D [%result1, #nvvm.wgmma_scale_out<one>],
      A [<u8>, #nvvm.wgmma_scale_in<one>, <row>], 
      B [<u8>, #nvvm.wgmma_scale_in<one>, <row>]
      : !mat16i32 -> !mat16i32
  %result3 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 8, k = 32>, 
      D [%result2, #nvvm.wgmma_scale_out<one>],
      A [<u8>, #nvvm.wgmma_scale_in<one>, <row>], 
      B [<u8>, #nvvm.wgmma_scale_in<one>, <row>]
      : !mat16i32 -> !mat16i32
  return %result3 : !mat16i32
}

// -----

!mat32f32 = !llvm.struct<(
  f32, f32, f32, f32, f32, f32, f32, f32, 
  f32, f32, f32, f32, f32, f32, f32, f32, 
  f32, f32, f32, f32, f32, f32, f32, f32, 
  f32, f32, f32, f32, f32, f32, f32, f32)>

// CHECK-LABEL: @wgmma_f32_tf32_tf32
func.func @wgmma_f32_tf32_tf32(%descA : i64, %descB : i64) -> !mat32f32 {  
  // CHECK: %[[RES:.+]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $34, 0;\0Awgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 {$0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31}, $32, $33, p, $35,  $36;\0A}\0A", "=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,l,l,n,n,n"
  // CHECK: %[[RES_2:.+]] = llvm.inline_asm has_side_effects asm_dialect = att "{\0A.reg .pred p;\0Asetp.ne.b32 p, $34, 0;\0Awgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 {$0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31}, $32, $33, p, $35,  $36;\0A}\0A", "=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,=f,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,l,l,n,n,n"
  %result = llvm.mlir.undef : !mat32f32
  %result1 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 64, k = 8>, 
      D [%result, #nvvm.wgmma_scale_out<one>],
      A [#nvvm.mma_type<tf32>, #nvvm.wgmma_scale_in<one>, #nvvm.mma_layout<row>], 
      B [#nvvm.mma_type<tf32>, #nvvm.wgmma_scale_in<one>, #nvvm.mma_layout<row>]
       : !mat32f32 -> !mat32f32
  %result2 = nvvm.wgmma.mma_async %descA, %descB, 
      #nvvm.shape<m = 64, n = 64, k = 8>, 
      D [%result1, #nvvm.wgmma_scale_out<one>],
      A [#nvvm.mma_type<tf32>, #nvvm.wgmma_scale_in<one>, #nvvm.mma_layout<row>], 
      B [#nvvm.mma_type<tf32>, #nvvm.wgmma_scale_in<one>, #nvvm.mma_layout<row>]
      : !mat32f32 -> !mat32f32
  return %result2 : !mat32f32
}
