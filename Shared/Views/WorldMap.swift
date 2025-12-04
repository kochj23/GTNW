//
//  WorldMap.swift
//  Global Thermal Nuclear War
//
//  Interactive world map display
//

import SwiftUI

struct WorldMapView: View {
    let gameState: GameState

    @State private var selectedCountry: Country?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map background
                Rectangle()
                    .fill(Color.black)

                // World map visualization
                Canvas { context, size in
                    drawWorldMap(context: context, size: size, geometry: geometry)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = value
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                        }
                )

                // Selected country info overlay
                if let selectedCountry = selectedCountry {
                    VStack {
                        Spacer()
                        countryInfoCard(selectedCountry)
                            .padding()
                    }
                }
            }
        }
    }

    private func drawWorldMap(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
        // Draw countries as circles at their coordinates
        for country in gameState.countries where !country.isDestroyed {
            let x = longitudeToX(country.coordinates.lon, width: size.width)
            let y = latitudeToY(country.coordinates.lat, height: size.height)

            let point = CGPoint(x: x, y: y)

            // Determine color based on status
            let color: Color
            if country.isPlayerControlled {
                color = AppSettings.terminalAmber
            } else if country.nuclearWarheads > 0 {
                color = AppSettings.terminalRed
            } else if !country.atWarWith.isEmpty {
                color = .orange
            } else {
                color = AppSettings.terminalGreen
            }

            // Draw circle for country
            let radius: CGFloat = country.isPlayerControlled ? 8 : (country.nuclearWarheads > 0 ? 6 : 4)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color)
            )

            // Draw glow for nuclear powers
            if country.nuclearWarheads > 0 {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius - 2, y: point.y - radius - 2, width: (radius + 2) * 2, height: (radius + 2) * 2)),
                    with: .color(color.opacity(0.3))
                )
            }

            // Draw radiation cloud
            if country.radiationLevel > 0 {
                let radiusMultiplier = CGFloat(country.radiationLevel) / 10.0
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius * radiusMultiplier, y: point.y - radius * radiusMultiplier,
                                          width: radius * radiusMultiplier * 2, height: radius * radiusMultiplier * 2)),
                    with: .color(AppSettings.terminalRed.opacity(0.2))
                )
            }
        }

        // Draw nuclear strike paths
        for strike in gameState.nuclearStrikes.suffix(10) {
            if let attacker = gameState.getCountry(id: strike.attacker),
               let target = gameState.getCountry(id: strike.target) {
                let x1 = longitudeToX(attacker.coordinates.lon, width: size.width)
                let y1 = latitudeToY(attacker.coordinates.lat, height: size.height)
                let x2 = longitudeToX(target.coordinates.lon, width: size.width)
                let y2 = latitudeToY(target.coordinates.lat, height: size.height)

                var path = Path()
                path.move(to: CGPoint(x: x1, y: y1))
                path.addLine(to: CGPoint(x: x2, y: y2))

                context.stroke(path, with: .color(AppSettings.terminalRed), lineWidth: 2)
            }
        }
    }

    private func longitudeToX(_ lon: Double, width: CGFloat) -> CGFloat {
        return CGFloat((lon + 180.0) / 360.0) * width
    }

    private func latitudeToY(_ lat: Double, height: CGFloat) -> CGFloat {
        return CGFloat((90.0 - lat) / 180.0) * height
    }

    private func countryInfoCard(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(country.flag)
                    .font(.system(size: 40))
                VStack(alignment: .leading) {
                    Text(country.name)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                    Text(country.capital)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    selectedCountry = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppSettings.terminalGreen)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    infoRow("Nuclear Warheads", "\(country.nuclearWarheads)")
                    infoRow("ICBMs", "\(country.icbmCount)")
                    infoRow("Population", "\(country.population)M")
                    infoRow("GDP", "$\(String(format: "%.1f", country.gdp))T")
                }
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    infoRow("Military Strength", "\(country.militaryStrength)")
                    infoRow("Damage", "\(country.damageLevel)%")
                    infoRow("Radiation", "\(country.radiationLevel)")
                    infoRow("Stability", "\(country.stability)")
                }
            }

            if country.isPlayerControlled {
                Text("YOUR NATION")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            }
        }
        .padding()
        .background(AppSettings.panelBackground.opacity(0.95))
        .border(AppSettings.terminalGreen, width: 2)
        .frame(maxWidth: 500)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
        }
    }
}
