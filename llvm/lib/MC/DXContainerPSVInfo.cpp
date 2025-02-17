//===- llvm/MC/DXContainerPSVInfo.cpp - DXContainer PSVInfo -----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/MC/DXContainerPSVInfo.h"
#include "llvm/BinaryFormat/DXContainer.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace llvm::mcdxbc;
using namespace llvm::dxbc::PSV;

void PSVRuntimeInfo::write(raw_ostream &OS, uint32_t Version) const {
  uint32_t InfoSize;
  uint32_t BindingSize;
  switch (Version) {
  case 0:
    InfoSize = sizeof(dxbc::PSV::v0::RuntimeInfo);
    BindingSize = sizeof(dxbc::PSV::v0::ResourceBindInfo);
    break;
  case 1:
    InfoSize = sizeof(dxbc::PSV::v1::RuntimeInfo);
    BindingSize = sizeof(dxbc::PSV::v0::ResourceBindInfo);
    break;
  case 2:
  default:
    InfoSize = sizeof(dxbc::PSV::v2::RuntimeInfo);
    BindingSize = sizeof(dxbc::PSV::v2::ResourceBindInfo);
  }
  // Write the size of the info.

  support::endian::write(OS, InfoSize, support::little);
  // Write the info itself.
  OS.write(reinterpret_cast<const char *>(&BaseData), InfoSize);

  uint32_t ResourceCount = static_cast<uint32_t>(Resources.size());

  support::endian::write(OS, ResourceCount, support::little);
  support::endian::write(OS, BindingSize, support::little);

  for (const auto &Res : Resources)
    OS.write(reinterpret_cast<const char *>(&Res), BindingSize);
}
