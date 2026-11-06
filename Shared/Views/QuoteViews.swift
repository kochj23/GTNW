//
//  QuoteViews.swift
//  Global Thermal Nuclear War
//
//  3.20.0: an epigraph — quote, source, and which shelf it came from.
//  Created by Jordan Koch.
//

import SwiftUI

struct EpigraphView: View {
    let quote: Quotation
    var compact = false

    private var shelfColor: Color {
        switch quote.kind {
        case .sacred: return AppSettings.terminalAmber
        case .sciFi: return .cyan
        case .military: return AppSettings.terminalGreen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("“\(quote.text)”")
                .font(.scaled(size: compact ? 11 : 14, design: .serif)).italic()
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("— \(quote.source)")
                    .font(.scaled(size: compact ? 10 : 12, design: .monospaced))
                    .foregroundColor(shelfColor)
                if !compact {
                    Text(quote.kind.rawValue.uppercased())
                        .font(.scaled(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(shelfColor.opacity(0.8))
                }
            }
        }
        .padding(compact ? 4 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().frame(width: 2).foregroundColor(shelfColor), alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quote.text). \(quote.source)")
    }
}
