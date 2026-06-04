//
//  PermissionChip.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import SwiftUI

enum PermissionStatus {
  case granted
  case denied
}

struct PermissionChip: View {
  let status: PermissionStatus
  var body: some View {
    switch status {
    case .granted:
      Text("허용됨")
        .font(.caption.bold())
        .foregroundStyle(.appSuccess)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.appSuccess.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    case .denied:
      Text("설정 필요")
        .font(.caption.bold())
        .foregroundStyle(.appDanger)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.appDanger.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
  }
}

#Preview {
  PermissionChip(status: .denied)
  PermissionChip(status: .granted)
}
