//
//  GameEngine+EnhancedWars.swift
//  Global Thermal Nuclear War
//
//  Enhanced war system integration with GameEngine
//  Created by Jordan Koch on 2025-12-11.
//

import Foundation

extension GameEngine {
    // MARK: - Enhanced Wars Storage

    /// Track enhanced wars alongside legacy wars
    var enhancedWars: [EnhancedWar] {
        get {
            // Retrieve from storage or convert legacy wars
            if let stored = _enhancedWarsCache {
                return stored
            }

            // Convert legacy wars to enhanced wars
            guard let gameState = gameState else { return [] }
            let enhanced = gameState.activeWars.map { war in
                EnhancedWar(
                    aggressor: war.aggressor,
                    defender: war.defender,
                    startTurn: war.startTurn,
                    intensity: war.intensity
                )
            }
            _enhancedWarsCache = enhanced
            return enhanced
        }
        set {
            _enhancedWarsCache = newValue
        }
    }

    private var _enhancedWarsCache: [EnhancedWar]? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.enhancedWarsKey) as? [EnhancedWar]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.enhancedWarsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private struct AssociatedKeys {
        static var enhancedWarsKey = "enhancedWarsKey"
    }

    // MARK: - Military Deployment

    /// Deploy military forces to an active war
    func deployMilitaryForces(warID: UUID, deployment: MilitaryDeployment) {
        guard var gameState = self.gameState else { return }
        guard let playerCountry = gameState.getPlayerCountry() else { return }

        // Find the enhanced war
        guard let warIndex = enhancedWars.firstIndex(where: { $0.id == warID }) else {
            addLog("❌ War not found", type: .error)
            return
        }

        var war = enhancedWars[warIndex]

        // Update player's deployment
        if war.aggressor == playerCountry.id {
            war.aggressorStats.deployment.infantry += deployment.infantry
            war.aggressorStats.deployment.tanks += deployment.tanks
            war.aggressorStats.deployment.artillery += deployment.artillery
            war.aggressorStats.deployment.aircraft += deployment.aircraft
            war.aggressorStats.deployment.ships += deployment.ships
        } else {
            war.defenderStats.deployment.infantry += deployment.infantry
            war.defenderStats.deployment.tanks += deployment.tanks
            war.defenderStats.deployment.artillery += deployment.artillery
            war.defenderStats.deployment.aircraft += deployment.aircraft
            war.defenderStats.deployment.ships += deployment.ships
        }

        // Calculate cost
        let cost = calculateDeploymentCost(deployment)
        if war.aggressor == playerCountry.id {
            war.economicCostAggressor += cost
        } else {
            war.economicCostDefender += cost
        }

        // Update war
        enhancedWars[warIndex] = war

        // Log the deployment
        addLog("🪖 Deployed \(deployment.totalUnits) military units (Cost: $\(String(format: "%.1f", cost))B)", type: .military)
    }

    /// Calculate the economic cost of a military deployment
    private func calculateDeploymentCost(_ deployment: MilitaryDeployment) -> Double {
        let infantryCost = Double(deployment.infantry) * 0.0001
        let tankCost = Double(deployment.tanks) * 0.005
        let artilleryCost = Double(deployment.artillery) * 0.002
        let aircraftCost = Double(deployment.aircraft) * 0.1
        let shipCost = Double(deployment.ships) * 1.0
        return infantryCost + tankCost + artilleryCost + aircraftCost + shipCost
    }

    // MARK: - Combat Resolution

    /// Resolve combat for all enhanced wars this turn
    func resolveEnhancedWarsCombat() {
        guard var gameState = self.gameState else { return }

        for i in 0..<enhancedWars.count {
            var war = enhancedWars[i]

            // Create combat statistics for this turn
            var combatStats = CombatStatistics(turn: gameState.turn, warID: war.id)

            // Calculate casualties based on deployments and intensity
            let aggressorStrength = calculateMilitaryStrength(war.aggressorStats.deployment, morale: war.aggressorStats.morale)
            let defenderStrength = calculateMilitaryStrength(war.defenderStats.deployment, morale: war.defenderStats.morale)

            // Aggressor casualties (inversely proportional to their strength)
            let aggressorCasualtyRate = calculateCasualtyRate(
                attackerStrength: aggressorStrength,
                defenderStrength: defenderStrength,
                intensity: war.intensity
            )

            let defenderCasualtyRate = calculateCasualtyRate(
                attackerStrength: defenderStrength,
                defenderStrength: aggressorStrength,
                intensity: war.intensity
            )

            // Calculate actual casualties
            combatStats.aggressorCasualties = calculateCasualties(
                deployment: war.aggressorStats.deployment,
                casualtyRate: aggressorCasualtyRate
            )

            combatStats.defenderCasualties = calculateCasualties(
                deployment: war.defenderStats.deployment,
                casualtyRate: defenderCasualtyRate
            )

            // Calculate equipment losses
            combatStats.aggressorEquipmentLosses = calculateEquipmentLosses(
                deployment: war.aggressorStats.deployment,
                lossRate: aggressorCasualtyRate
            )

            combatStats.defenderEquipmentLosses = calculateEquipmentLosses(
                deployment: war.defenderStats.deployment,
                lossRate: defenderCasualtyRate
            )

            // Territory changes
            let strengthDifference = aggressorStrength - defenderStrength
            combatStats.territoryGained = Int(strengthDifference * 100.0)

            // Battle intensity
            combatStats.battlesThisTurn = max(1, war.intensity)
            combatStats.intensity = war.intensity

            // Update war totals
            war.aggressorStats.totalCasualties.dead += combatStats.aggressorCasualties.dead
            war.aggressorStats.totalCasualties.wounded += combatStats.aggressorCasualties.wounded
            war.defenderStats.totalCasualties.dead += combatStats.defenderCasualties.dead
            war.defenderStats.totalCasualties.wounded += combatStats.defenderCasualties.wounded

            war.aggressorStats.totalEquipmentLosses.tanksDestroyed += combatStats.aggressorEquipmentLosses.tanksDestroyed
            war.aggressorStats.totalEquipmentLosses.aircraftDestroyed += combatStats.aggressorEquipmentLosses.aircraftDestroyed
            war.defenderStats.totalEquipmentLosses.tanksDestroyed += combatStats.defenderEquipmentLosses.tanksDestroyed
            war.defenderStats.totalEquipmentLosses.aircraftDestroyed += combatStats.defenderEquipmentLosses.aircraftDestroyed

            // Adjust morale based on casualties
            war.aggressorStats.morale = max(0, war.aggressorStats.morale - Int(aggressorCasualtyRate * 10))
            war.defenderStats.morale = max(0, war.defenderStats.morale - Int(defenderCasualtyRate * 10))

            // Update deployments (remove casualties)
            war.aggressorStats.deployment.infantry = max(0, war.aggressorStats.deployment.infantry - combatStats.aggressorCasualties.dead - combatStats.aggressorCasualties.wounded)
            war.defenderStats.deployment.infantry = max(0, war.defenderStats.deployment.infantry - combatStats.defenderCasualties.dead - combatStats.defenderCasualties.wounded)

            war.aggressorStats.deployment.tanks = max(0, war.aggressorStats.deployment.tanks - combatStats.aggressorEquipmentLosses.tanksDestroyed)
            war.defenderStats.deployment.tanks = max(0, war.defenderStats.deployment.tanks - combatStats.defenderEquipmentLosses.tanksDestroyed)

            war.aggressorStats.deployment.aircraft = max(0, war.aggressorStats.deployment.aircraft - combatStats.aggressorEquipmentLosses.aircraftDestroyed)
            war.defenderStats.deployment.aircraft = max(0, war.defenderStats.deployment.aircraft - combatStats.defenderEquipmentLosses.aircraftDestroyed)

            // Add combat stats to history
            war.combatHistory.append(combatStats)

            // Update turn
            war.currentTurn = gameState.turn

            // Update total casualties in game state
            gameState.totalCasualties += combatStats.totalCasualties

            // Save war back
            enhancedWars[i] = war

            // Log combat results
            if combatStats.totalCasualties > 1000 {
                addLog("⚔️ Combat in \(getCountryName(war.aggressor)) vs \(getCountryName(war.defender)): \(combatStats.totalCasualties.formatted()) casualties", type: .war)
            }
        }

        self.gameState = gameState
    }

    // MARK: - Calculation Helpers

    private func calculateMilitaryStrength(_ deployment: MilitaryDeployment, morale: Int) -> Double {
        let infantryPower = Double(deployment.infantry) * 0.001
        let tankPower = Double(deployment.tanks) * 1.0
        let artilleryPower = Double(deployment.artillery) * 0.8
        let aircraftPower = Double(deployment.aircraft) * 5.0
        let shipPower = Double(deployment.ships) * 10.0

        let totalPower = infantryPower + tankPower + artilleryPower + aircraftPower + shipPower
        let moraleMultiplier = Double(morale) / 100.0

        return totalPower * moraleMultiplier
    }

    private func calculateCasualtyRate(attackerStrength: Double, defenderStrength: Double, intensity: Int) -> Double {
        let strengthRatio = defenderStrength / max(1.0, attackerStrength)
        let baseRate = 0.05 * Double(intensity) / 10.0  // 5% base at max intensity
        return baseRate * strengthRatio
    }

    private func calculateCasualties(deployment: MilitaryDeployment, casualtyRate: Double) -> CombatCasualties {
        let totalInfantry = deployment.infantry
        let totalCasualties = Int(Double(totalInfantry) * casualtyRate)

        // Split between dead and wounded (roughly 1:2 ratio)
        let dead = totalCasualties / 3
        let wounded = (totalCasualties * 2) / 3

        return CombatCasualties(
            dead: dead,
            wounded: wounded,
            missing: Int(Double(totalInfantry) * casualtyRate * 0.05),
            captured: Int(Double(totalInfantry) * casualtyRate * 0.02)
        )
    }

    private func calculateEquipmentLosses(deployment: MilitaryDeployment, lossRate: Double) -> EquipmentLosses {
        return EquipmentLosses(
            tanksDestroyed: Int(Double(deployment.tanks) * lossRate * 0.8),
            artilleryDestroyed: Int(Double(deployment.artillery) * lossRate * 0.6),
            aircraftDestroyed: Int(Double(deployment.aircraft) * lossRate * 0.4),
            shipsDestroyed: Int(Double(deployment.ships) * lossRate * 0.2)
        )
    }

    private func getCountryName(_ id: String) -> String {
        gameState?.getCountry(id: id)?.name ?? id
    }
}
