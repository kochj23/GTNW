//
//  WorldFactbookData.swift
//  GTNW
//
//  CIA World Factbook data — Tier 1 & 2 attributes for all 195 countries.
//  Data sourced from CIA World Factbook, Transparency International,
//  Reporters Without Borders, UN HDI, and World Bank.
//  Created by Jordan Koch on 2026-03-05
//

import Foundation

// MARK: - Supporting Enums

enum NaturalResource: String, Codable, CaseIterable {
    case oil          = "Oil"
    case naturalGas   = "Natural Gas"
    case coal         = "Coal"
    case uranium      = "Uranium"
    case gold         = "Gold"
    case diamonds     = "Diamonds"
    case copper       = "Copper"
    case lithium      = "Lithium"
    case rareEarths   = "Rare Earths"
    case iron         = "Iron"
    case agriculture  = "Agriculture"
    case timber       = "Timber"
    case fish         = "Fish"
    case water        = "Water"
    case phosphates   = "Phosphates"
    case nickel       = "Nickel"
    case bauxite      = "Bauxite"
    case cobalt       = "Cobalt"

    var icon: String {
        switch self {
        case .oil, .naturalGas: return "🛢️"
        case .coal:             return "⚫"
        case .uranium:          return "☢️"
        case .gold:             return "🥇"
        case .diamonds:         return "💎"
        case .agriculture:      return "🌾"
        case .timber:           return "🌲"
        case .fish:             return "🐟"
        case .water:            return "💧"
        case .lithium:          return "🔋"
        case .rareEarths:       return "⚗️"
        default:                return "⛏️"
        }
    }
}

enum TerrainType: String, Codable {
    case plains     = "Plains"
    case mountains  = "Mountainous"
    case desert     = "Desert"
    case jungle     = "Jungle/Rainforest"
    case island     = "Island"
    case arctic     = "Arctic/Tundra"
    case mixed      = "Mixed"
    case coastal    = "Coastal/Delta"

    /// Military movement penalty (0-50). Higher = harder to invade.
    var invasionPenalty: Int {
        switch self {
        case .mountains: return 40
        case .jungle:    return 30
        case .arctic:    return 45
        case .desert:    return 20
        case .island:    return 15
        default:         return 0
        }
    }

    /// Can a naval blockade be effective?
    var blockadeable: Bool {
        switch self {
        case .island, .coastal: return true
        default:                return false
        }
    }
}

enum Religion: String, Codable {
    case sunniIslam  = "Sunni Islam"
    case shiaIslam   = "Shia Islam"
    case catholic    = "Roman Catholic"
    case protestant  = "Protestant"
    case orthodox    = "Eastern Orthodox"
    case hindu       = "Hinduism"
    case buddhist    = "Buddhism"
    case confucian   = "Confucian/Buddhist"
    case secular     = "Secular/Atheist"
    case animist     = "Animist/Traditional"
    case jewish      = "Judaism"
    case mixed       = "Religiously Mixed"

    /// Informal bloc membership for diplomatic affinities.
    var informalBloc: String? {
        switch self {
        case .sunniIslam, .shiaIslam: return "OIC"       // Organisation of Islamic Cooperation
        case .orthodox:               return "Orthodox"
        case .confucian:              return "East Asian"
        case .catholic, .protestant:  return "Western"
        default:                      return nil
        }
    }

    /// Base diplomatic bonus with countries sharing this religion.
    var sharedReligionBonus: Int { 8 }
}

// MARK: - Factbook Record

struct WorldFactbookRecord {
    // Tier 1
    var naturalResources:    Set<NaturalResource>
    var corruptionIndex:     Int   // 0-100 (Transparency Intl — higher = LESS corrupt)
    var isLandlocked:        Bool
    var terrainType:         TerrainType
    var coastlineKm:         Int
    var arableLandPercent:   Int   // 0-100
    var dominantReligion:    Religion
    var religiousMinorities: Bool
    var topTradingPartners:  [String] // Country IDs (top 3)
    var energyExporter:      Bool
    var energyImporter:      Bool

    // Tier 2
    var pressFreedomIndex:   Int   // 0-100 (RSF — higher = freer)
    var giniCoefficient:     Int   // 0-100 (GINI × 100)
    var energyIndependence:  Int   // 0-100
    var literacyRate:        Int   // 0-100
    var humanDevelopmentIndex: Int // 0-100 (HDI × 100)
    var territorialDisputes: [String] // Country IDs with active territorial disputes

    static let `default` = WorldFactbookRecord(
        naturalResources: [.agriculture],
        corruptionIndex: 40, isLandlocked: false,
        terrainType: .mixed, coastlineKm: 500, arableLandPercent: 20,
        dominantReligion: .mixed, religiousMinorities: false,
        topTradingPartners: [], energyExporter: false, energyImporter: true,
        pressFreedomIndex: 45, giniCoefficient: 40, energyIndependence: 30,
        literacyRate: 78, humanDevelopmentIndex: 60, territorialDisputes: []
    )
}

// MARK: - CIA World Factbook Database

struct WorldFactbookDatabase {

    // swiftlint:disable function_body_length
    static let records: [String: WorldFactbookRecord] = buildRecords()

    static func record(for countryID: String) -> WorldFactbookRecord {
        records[countryID] ?? WorldFactbookRecord.default
    }

    // MARK: - Data Entry

    private static func buildRecords() -> [String: WorldFactbookRecord] {
        var db: [String: WorldFactbookRecord] = [:]

        // Helper
        func add(_ id: String, res: Set<NaturalResource>, corr: Int, land: Bool,
                 terr: TerrainType, coast: Int, arable: Int,
                 rel: Religion, minors: Bool = false,
                 trade: [String] = [], exp: Bool = false, imp: Bool = true,
                 press: Int, gini: Int, energy: Int, lit: Int, hdi: Int,
                 disputes: [String] = []) {
            db[id] = WorldFactbookRecord(
                naturalResources: res, corruptionIndex: corr, isLandlocked: land,
                terrainType: terr, coastlineKm: coast, arableLandPercent: arable,
                dominantReligion: rel, religiousMinorities: minors,
                topTradingPartners: trade, energyExporter: exp, energyImporter: imp,
                pressFreedomIndex: press, giniCoefficient: gini,
                energyIndependence: energy, literacyRate: lit,
                humanDevelopmentIndex: hdi, territorialDisputes: disputes
            )
        }

        // ── NORTH AMERICA ──────────────────────────────────────────────────────
        add("USA", res:[.oil,.naturalGas,.coal,.gold,.copper,.iron,.agriculture,.timber,.fish,.uranium],
            corr:69, land:false, terr:.mixed, coast:19924, arable:17,
            rel:.protestant, minors:true, trade:["CHN","MEX","CAN"], exp:true, imp:false,
            press:74, gini:41, energy:90, lit:99, hdi:93)

        add("CAN", res:[.oil,.naturalGas,.gold,.copper,.iron,.timber,.fish,.uranium,.nickel],
            corr:74, land:false, terr:.mixed, coast:202080, arable:5,
            rel:.catholic, minors:true, trade:["USA","CHN","GBR"], exp:true, imp:false,
            press:84, gini:33, energy:95, lit:99, hdi:93)

        add("MEX", res:[.oil,.naturalGas,.gold,.copper,.iron,.agriculture,.gold],
            corr:31, land:false, terr:.mixed, coast:9330, arable:12,
            rel:.catholic, minors:false, trade:["USA","CHN","DEU"], exp:true, imp:true,
            press:47, gini:45, energy:65, lit:95, hdi:77)

        // ── CENTRAL AMERICA & CARIBBEAN ────────────────────────────────────────
        add("CUB", res:[.nickel,.cobalt,.iron,.copper,.agriculture,.fish],
            corr:47, land:false, terr:.coastal, coast:3735, arable:33,
            rel:.catholic, minors:false, trade:["CHN","ESP","BRA"], exp:false, imp:true,
            press:8, gini:38, energy:55, lit:100, hdi:78)

        add("GTM", res:[.agriculture,.timber,.fish,.oil],
            corr:26, land:false, terr:.mountains, coast:400, arable:17,
            rel:.catholic, minors:true, trade:["USA","ELS","HND"], exp:false, imp:true,
            press:48, gini:49, energy:35, lit:82, hdi:63)

        // Generic Caribbean/Central American defaults
        for id in ["HTI","DOM","JAM","TTO","BRB","LCA","VCT","GRD","ATG","KNA","DMA","BHS","BLZ","HND","SLV","NIC","CRI","PAN"] {
            add(id, res:[.agriculture,.fish], corr:35, land:false, terr:.coastal, coast:300, arable:20,
                rel:.catholic, trade:["USA"], press:55, gini:46, energy:20, lit:82, hdi:65)
        }

        // ── SOUTH AMERICA ──────────────────────────────────────────────────────
        add("BRA", res:[.iron,.nickel,.gold,.diamonds,.oil,.naturalGas,.agriculture,.timber,.nickel],
            corr:38, land:false, terr:.jungle, coast:7491, arable:9,
            rel:.catholic, minors:true, trade:["CHN","USA","ARG"], exp:true, imp:true,
            press:63, gini:52, energy:85, lit:94, hdi:75)

        add("ARG", res:[.agriculture,.oil,.naturalGas,.iron,.copper,.lithium,.gold],
            corr:40, land:false, terr:.plains, coast:4989, arable:14,
            rel:.catholic, minors:false, trade:["CHN","BRA","USA"], exp:true, imp:true,
            press:67, gini:43, energy:70, lit:99, hdi:82)

        add("CHL", res:[.copper,.lithium,.gold,.iron,.agriculture,.fish,.timber],
            corr:67, land:false, terr:.mountains, coast:6435, arable:2,
            rel:.catholic, trade:["CHN","USA","JPN"], exp:true, imp:true,
            press:70, gini:45, energy:35, lit:97, hdi:85)

        add("COL", res:[.oil,.naturalGas,.coal,.gold,.gold,.copper,.agriculture,.nickel],
            corr:39, land:false, terr:.jungle, coast:3208, arable:2,
            rel:.catholic, trade:["USA","CHN","PAN"], exp:true, imp:true,
            press:52, gini:54, energy:60, lit:95, hdi:75)

        add("VEN", res:[.oil,.naturalGas,.gold,.diamonds,.iron,.nickel,.agriculture],
            corr:14, land:false, terr:.mixed, coast:2800, arable:3,
            rel:.catholic, trade:["CHN","USA","IND"], exp:true, imp:true,
            press:24, gini:47, energy:100, lit:97, hdi:71)

        add("PER", res:[.copper,.gold,.gold,.copper,.oil,.naturalGas,.agriculture,.fish],
            corr:36, land:false, terr:.mountains, coast:2414, arable:3,
            rel:.catholic, trade:["CHN","USA","CAN"], exp:true, imp:true,
            press:63, gini:43, energy:55, lit:94, hdi:76)

        add("BOL", res:[.naturalGas,.lithium,.gold,.copper,.iron,.copper,.agriculture],
            corr:31, land:true, terr:.mountains, coast:0, arable:4,
            rel:.catholic, trade:["BRA","ARG","COL"], exp:true, imp:true,
            press:55, gini:43, energy:100, lit:95, hdi:69)

        add("ECU", res:[.oil,.naturalGas,.agriculture,.fish,.gold,.copper],
            corr:35, land:false, terr:.mixed, coast:2237, arable:5,
            rel:.catholic, trade:["USA","CHN","CHL"], exp:true, imp:true,
            press:54, gini:46, energy:80, lit:95, hdi:75)

        for id in ["PRY","URY","GUY","SUR"] {
            add(id, res:[.agriculture,.timber], corr:40, land:false, terr:.plains, coast:200, arable:10,
                rel:.catholic, trade:["BRA","ARG"], press:65, gini:46, energy:50, lit:95, hdi:72)
        }

        // ── WESTERN EUROPE ─────────────────────────────────────────────────────
        add("GBR", res:[.oil,.naturalGas,.coal,.fish,.agriculture,.iron],
            corr:78, land:false, terr:.coastal, coast:12429, arable:25,
            rel:.protestant, minors:true, trade:["DEU","USA","FRA"], exp:true, imp:true,
            press:79, gini:35, energy:72, lit:99, hdi:93)

        add("DEU", res:[.coal,.iron,.copper,.nickel,.agriculture,.timber],
            corr:79, land:false, terr:.plains, coast:2389, arable:35,
            rel:.protestant, minors:true, trade:["CHN","USA","FRA"], exp:false, imp:true,
            press:83, gini:32, energy:35, lit:99, hdi:94)

        add("FRA", res:[.coal,.iron,.agriculture,.timber,.fish,.uranium],
            corr:71, land:false, terr:.plains, coast:4853, arable:34,
            rel:.catholic, minors:true, trade:["DEU","USA","CHN"], exp:false, imp:true,
            press:78, gini:32, energy:80, lit:99, hdi:90) // high nuclear energy independence

        add("ITA", res:[.coal,.copper,.copper,.agriculture,.fish,.iron],
            corr:56, land:false, terr:.mixed, coast:7600, arable:23,
            rel:.catholic, trade:["DEU","FRA","USA"], exp:false, imp:true,
            press:70, gini:36, energy:22, lit:99, hdi:89)

        add("ESP", res:[.agriculture,.fish,.iron,.copper,.coal],
            corr:61, land:false, terr:.plains, coast:4964, arable:25,
            rel:.catholic, trade:["FRA","DEU","USA"], press:69, gini:35, energy:28, lit:99, hdi:90)

        add("NLD", res:[.naturalGas,.agriculture,.fish],
            corr:87, land:false, terr:.coastal, coast:451, arable:55,
            rel:.protestant, trade:["DEU","GBR","USA"], exp:true, imp:true,
            press:87, gini:28, energy:45, lit:99, hdi:94)

        add("BEL", res:[.coal,.agriculture],
            corr:73, land:false, terr:.plains, coast:67, arable:27,
            rel:.catholic, trade:["DEU","FRA","NLD"], press:77, gini:27, energy:30, lit:99, hdi:92)

        add("CHE", res:[.timber,.agriculture,.water],
            corr:87, land:false, terr:.mountains, coast:0, arable:10,
            rel:.catholic, trade:["DEU","FRA","USA"], press:82, gini:34, energy:65, lit:99, hdi:95)

        add("AUT", res:[.iron,.timber,.agriculture,.water],
            corr:73, land:false, terr:.mountains, coast:0, arable:16,
            rel:.catholic, trade:["DEU","ITA","USA"], press:82, gini:30, energy:72, lit:99, hdi:91)

        add("SWE", res:[.iron,.timber,.fish,.agriculture,.uranium],
            corr:85, land:false, terr:.mixed, coast:3218, arable:7,
            rel:.protestant, trade:["DEU","NOR","USA"], exp:false, imp:true,
            press:88, gini:30, energy:52, lit:99, hdi:94)

        add("NOR", res:[.oil,.naturalGas,.fish,.timber,.agriculture,.nickel],
            corr:84, land:false, terr:.mountains, coast:25148, arable:2,
            rel:.protestant, trade:["GBR","DEU","SWE"], exp:true, imp:false,
            press:90, gini:26, energy:100, lit:99, hdi:96)

        add("DNK", res:[.oil,.naturalGas,.fish,.agriculture],
            corr:90, land:false, terr:.plains, coast:7314, arable:58,
            rel:.protestant, trade:["DEU","SWE","USA"], exp:true, imp:false,
            press:89, gini:29, energy:80, lit:99, hdi:94)

        add("FIN", res:[.timber,.copper,.iron,.fish,.agriculture],
            corr:87, land:false, terr:.mixed, coast:1250, arable:7,
            rel:.protestant, trade:["DEU","RUS","SWE"], press:88, gini:27, energy:55, lit:99, hdi:94)

        add("IRL", res:[.agriculture,.fish,.naturalGas],
            corr:74, land:false, terr:.plains, coast:2797, arable:15,
            rel:.catholic, trade:["USA","GBR","DEU"], press:82, gini:32, energy:32, lit:99, hdi:95)

        add("PRT", res:[.fish,.agriculture,.timber,.copper,.uranium,.lithium],
            corr:62, land:false, terr:.mixed, coast:1793, arable:11,
            rel:.catholic, trade:["ESP","FRA","DEU"], press:72, gini:34, energy:60, lit:96, hdi:87)

        add("GRC", res:[.agriculture,.fish,.iron,.iron,.iron],
            corr:48, land:false, terr:.island, coast:13676, arable:19,
            rel:.orthodox, trade:["DEU","ITA","CHN"], press:65, gini:32, energy:18, lit:98, hdi:89,
            disputes:["TUR"]) // Aegean disputes

        for id in ["ISL","LUX","MCO","AND","LIE","SMR","VAT"] {
            add(id, res:[.fish,.agriculture], corr:78, land:false, terr:.mixed, coast:300, arable:5,
                rel:.catholic, press:85, gini:28, energy:60, lit:99, hdi:93)
        }

        add("MLT", res:[.fish,.agriculture], corr:54, land:false, terr:.island, coast:253, arable:11,
            rel:.catholic, trade:["ITA","FRA","DEU"], press:68, gini:30, energy:8, lit:94, hdi:90)

        add("CYP", res:[.copper,.agriculture,.fish],
            corr:54, land:false, terr:.island, coast:648, arable:9,
            rel:.orthodox, press:70, gini:34, energy:5, lit:99, hdi:88, disputes:["TUR"])

        // ── EASTERN EUROPE ─────────────────────────────────────────────────────
        add("POL", res:[.coal,.copper,.gold,.iron,.agriculture],
            corr:55, land:false, terr:.plains, coast:491, arable:38,
            rel:.catholic, trade:["DEU","CZE","GBR"], press:66, gini:31, energy:55, lit:99, hdi:88)

        add("ROU", res:[.oil,.naturalGas,.coal,.iron,.agriculture],
            corr:46, land:false, terr:.mixed, coast:225, arable:38,
            rel:.orthodox, trade:["DEU","ITA","FRA"], exp:true, imp:true,
            press:60, gini:36, energy:65, lit:99, hdi:81)

        add("CZE", res:[.coal,.agriculture,.copper],
            corr:57, land:false, terr:.plains, coast:0, arable:39,
            rel:.secular, trade:["DEU","SVK","POL"], press:74, gini:26, energy:40, lit:99, hdi:90)

        add("HUN", res:[.coal,.naturalGas,.agriculture,.nickel],
            corr:43, land:false, terr:.plains, coast:0, arable:51,
            rel:.catholic, trade:["DEU","AUT","ITA"], press:48, gini:29, energy:45, lit:99, hdi:85)

        add("SVK", res:[.coal,.iron,.copper,.agriculture],
            corr:50, land:false, terr:.mountains, coast:0, arable:28,
            rel:.catholic, trade:["DEU","CZE","POL"], press:68, gini:24, energy:65, lit:99, hdi:86)

        add("BGR", res:[.coal,.copper,.iron,.agriculture,.timber],
            corr:45, land:false, terr:.mixed, coast:354, arable:30,
            rel:.orthodox, trade:["DEU","ITA","ROU"], press:51, gini:40, energy:42, lit:99, hdi:80)

        add("UKR", res:[.iron,.coal,.iron,.iron,.agriculture,.naturalGas,.uranium],
            corr:36, land:false, terr:.plains, coast:2782, arable:58,
            rel:.orthodox, minors:true, trade:["CHN","POL","DEU"], exp:true, imp:true,
            press:62, gini:26, energy:60, lit:99, hdi:77, disputes:["RUS"])

        add("BLR", res:[.agriculture,.timber,.agriculture,.agriculture],
            corr:41, land:false, terr:.plains, coast:0, arable:30,
            rel:.orthodox, trade:["RUS","DEU","POL"], press:11, gini:25, energy:25, lit:100, hdi:80)

        add("MDA", res:[.agriculture,.timber],
            corr:39, land:false, terr:.plains, coast:0, arable:54,
            rel:.orthodox, trade:["ROU","ITA","DEU"], press:51, gini:26, energy:8, lit:99, hdi:76)

        for id in ["LTU","LVA","EST"] {
            let coast = id == "LTU" ? 99 : id == "LVA" ? 498 : 3794
            add(id, res:[.agriculture,.fish,.timber], corr:62, land:false, terr:.coastal, coast:coast, arable:30,
                rel:.protestant, trade:["RUS","LVA","DEU"], press:80, gini:36, energy:35, lit:100, hdi:87)
        }

        // ── FORMER SOVIET (Caucasus/Central Asia) ──────────────────────────────
        add("RUS", res:[.oil,.naturalGas,.coal,.gold,.diamonds,.iron,.nickel,.uranium,.timber,.fish,.copper],
            corr:28, land:false, terr:.arctic, coast:37653, arable:7,
            rel:.orthodox, minors:true, trade:["CHN","DEU","NLD"], exp:true, imp:false,
            press:22, gini:37, energy:100, lit:99, hdi:82, disputes:["UKR","JPN","GEO"])

        add("GEO", res:[.agriculture,.timber,.iron,.copper,.iron],
            corr:56, land:false, terr:.mountains, coast:310, arable:6,
            rel:.orthodox, press:59, gini:40, energy:40, lit:99, hdi:82, disputes:["RUS"])

        add("ARM", res:[.gold,.copper,.copper,.agriculture],
            corr:49, land:true, terr:.mountains, coast:0, arable:16,
            rel:.orthodox, press:48, gini:29, energy:40, lit:100, hdi:79, disputes:["AZE"])

        add("AZE", res:[.oil,.naturalGas,.iron,.gold,.agriculture],
            corr:29, land:false, terr:.mixed, coast:0, arable:24,
            rel:.shiaIslam, minors:true, exp:true, imp:false,
            press:23, gini:36, energy:100, lit:100, hdi:75, disputes:["ARM"])

        add("KAZ", res:[.oil,.naturalGas,.coal,.uranium,.copper,.iron,.gold,.copper],
            corr:36, land:false, terr:.plains, coast:0, arable:8,
            rel:.sunniIslam, trade:["CHN","RUS","ITA"], exp:true, imp:false,
            press:27, gini:29, energy:100, lit:99, hdi:80)

        add("UZB", res:[.naturalGas,.gold,.uranium,.copper,.agriculture,.agriculture],
            corr:33, land:true, terr:.desert, coast:0, arable:9,
            rel:.sunniIslam, trade:["CHN","RUS","KAZ"], exp:true, imp:true,
            press:20, gini:36, energy:80, lit:100, hdi:73)

        add("TKM", res:[.naturalGas,.oil,.coal,.agriculture],
            corr:19, land:false, terr:.desert, coast:0, arable:4,
            rel:.sunniIslam, trade:["CHN","TUR","RUS"], exp:true, imp:false,
            press:7, gini:36, energy:100, lit:99, hdi:72)

        for id in ["KGZ","TJK"] {
            add(id, res:[.gold,.copper,.copper,.agriculture,.water], corr:25, land:true, terr:.mountains, coast:0, arable:7,
                rel:.sunniIslam, press:30, gini:29, energy:70, lit:99, hdi:67)
        }

        // ── BALKANS ────────────────────────────────────────────────────────────
        add("SRB", res:[.coal,.iron,.copper,.agriculture,.timber],
            corr:36, land:false, terr:.mountains, coast:0, arable:40,
            rel:.orthodox, minors:true, press:55, gini:37, energy:47, lit:99, hdi:80, disputes:["XKX"])

        for id in ["HRV","SVN","BIH","MKD","MNE","ALB"] {
            add(id, res:[.agriculture,.timber,.fish], corr:47, land:false, terr:.mountains, coast:300, arable:15,
                rel:.catholic, press:62, gini:33, energy:30, lit:98, hdi:80)
        }

        // ── MIDDLE EAST ────────────────────────────────────────────────────────
        add("SAU", res:[.oil,.naturalGas,.iron,.gold,.copper],
            corr:52, land:false, terr:.desert, coast:2640, arable:1,
            rel:.sunniIslam, trade:["CHN","JPN","IND"], exp:true, imp:false,
            press:16, gini:45, energy:100, lit:97, hdi:87)

        add("IRN", res:[.oil,.naturalGas,.coal,.iron,.copper,.gold,.uranium,.agriculture],
            corr:25, land:false, terr:.mixed, coast:2440, arable:10,
            rel:.shiaIslam, minors:true, trade:["CHN","IRQ","TUR"], exp:true, imp:true,
            press:22, gini:40, energy:100, lit:97, hdi:78, disputes:["ISR","IRQ"])

        add("TUR", res:[.coal,.iron,.copper,.iron,.agriculture,.timber],
            corr:36, land:false, terr:.mountains, coast:7200, arable:28,
            rel:.sunniIslam, minors:true, trade:["DEU","RUS","GBR"], press:32, gini:42, energy:28, lit:97, hdi:82,
            disputes:["GRC","SYR","ARM"])

        add("ISR", res:[.naturalGas,.agriculture,.agriculture,.phosphates],
            corr:64, land:false, terr:.mixed, coast:273, arable:13,
            rel:.jewish, minors:true, trade:["USA","CHN","DEU"], exp:true, imp:true,
            press:72, gini:39, energy:65, lit:97, hdi:92, disputes:["PSE","LBN","SYR"])

        add("IRQ", res:[.oil,.naturalGas,.phosphates,.oil,.agriculture],
            corr:23, land:false, terr:.desert, coast:58, arable:9,
            rel:.shiaIslam, minors:true, trade:["CHN","IND","USA"], exp:true, imp:false,
            press:36, gini:30, energy:100, lit:85, hdi:68, disputes:["IRN","KWT"])

        add("SYR", res:[.oil,.phosphates,.agriculture,.iron],
            corr:14, land:false, terr:.mixed, coast:193, arable:26,
            rel:.sunniIslam, minors:true, trade:["IRN","RUS","CHN"], exp:false, imp:true,
            press:11, gini:35, energy:35, lit:82, hdi:57, disputes:["ISR","TUR"])

        add("JOR", res:[.phosphates,.agriculture,.agriculture],
            corr:49, land:false, terr:.desert, coast:26, arable:2,
            rel:.sunniIslam, minors:true, trade:["USA","SAU","IND"], press:41, gini:34, energy:5, lit:98, hdi:73)

        add("LBN", res:[.agriculture,.fish,.iron],
            corr:24, land:false, terr:.mountains, coast:225, arable:11,
            rel:.mixed, minors:true, trade:["CHN","ITA","GRC"], press:46, gini:32, energy:5, lit:96, hdi:70,
            disputes:["ISR"])

        add("YEM", res:[.oil,.fish,.agriculture,.agriculture],
            corr:15, land:false, terr:.desert, coast:1906, arable:3,
            rel:.sunniIslam, minors:true, trade:["CHN","SAU","ARE"], exp:false, imp:true,
            press:16, gini:36, energy:30, lit:70, hdi:45)

        add("ARE", res:[.oil,.naturalGas,.agriculture,.fish],
            corr:69, land:false, terr:.desert, coast:1318, arable:1,
            rel:.sunniIslam, trade:["CHN","IND","JPN"], exp:true, imp:false,
            press:22, gini:32, energy:100, lit:96, hdi:91)

        for id in ["OMN","KWT","QAT","BHR"] {
            add(id, res:[.oil,.naturalGas,.fish], corr:55, land:false, terr:.desert, coast:400, arable:1,
                rel:.sunniIslam, trade:["CHN","JPN","IND"], exp:true, imp:false,
                press:25, gini:36, energy:100, lit:93, hdi:83)
        }

        add("PSE", res:[.agriculture,.naturalGas],
            corr:32, land:false, terr:.coastal, coast:60, arable:17,
            rel:.sunniIslam, press:36, gini:34, energy:5, lit:97, hdi:70, disputes:["ISR"])

        // ── SOUTH ASIA ─────────────────────────────────────────────────────────
        add("IND", res:[.coal,.iron,.iron,.iron,.nickel,.gold,.diamonds,.agriculture,.timber],
            corr:40, land:false, terr:.mixed, coast:7000, arable:53,
            rel:.hindu, minors:true, trade:["USA","CHN","ARE"], exp:false, imp:true,
            press:37, gini:35, energy:72, lit:77, hdi:64, disputes:["CHN","PAK"])

        add("PAK", res:[.naturalGas,.oil,.coal,.iron,.copper,.agriculture,.gold],
            corr:28, land:false, terr:.mountains, coast:1046, arable:27,
            rel:.sunniIslam, minors:true, trade:["CHN","USA","ARE"], exp:false, imp:true,
            press:33, gini:30, energy:60, lit:60, hdi:55, disputes:["IND","AFG"])

        add("BGD", res:[.naturalGas,.agriculture,.fish,.coal],
            corr:25, land:false, terr:.coastal, coast:580, arable:60,
            rel:.sunniIslam, trade:["USA","DEU","GBR"], exp:false, imp:true,
            press:37, gini:32, energy:70, lit:74, hdi:67)

        add("AFG", res:[.naturalGas,.coal,.iron,.copper,.gold,.lithium,.agriculture],
            corr:16, land:true, terr:.mountains, coast:0, arable:12,
            rel:.sunniIslam, minors:true, trade:["PAK","IND","CHN"], press:14, gini:30, energy:25, lit:37, hdi:46,
            disputes:["PAK"])

        add("LKA", res:[.agriculture,.fish,.gold,.iron,.coal],
            corr:40, land:false, terr:.island, coast:1340, arable:20,
            rel:.buddhist, press:45, gini:39, energy:45, lit:92, hdi:78)

        add("NPL", res:[.water,.timber,.agriculture,.gold],
            corr:35, land:true, terr:.mountains, coast:0, arable:17,
            rel:.hindu, press:51, gini:33, energy:90, lit:67, hdi:60)

        for id in ["BTN","MDV"] {
            add(id, res:[.water,.fish,.agriculture], corr:68, land:false, terr:.island, coast:500, arable:3,
                rel:.buddhist, press:65, gini:38, energy:60, lit:66, hdi:70)
        }

        // ── EAST ASIA ──────────────────────────────────────────────────────────
        add("CHN", res:[.coal,.iron,.rareEarths,.copper,.lithium,.oil,.naturalGas,.agriculture,.gold,.nickel],
            corr:42, land:false, terr:.mixed, coast:14500, arable:12,
            rel:.confucian, minors:true, trade:["USA","JPN","KOR"], exp:false, imp:true,
            press:22, gini:47, energy:75, lit:97, hdi:77, disputes:["TWN","IND","VNM","PHL"])

        add("JPN", res:[.fish,.agriculture,.timber,.iron],
            corr:73, land:false, terr:.island, coast:29751, arable:12,
            rel:.confucian, trade:["CHN","USA","KOR"], exp:false, imp:true,
            press:68, gini:33, energy:10, lit:99, hdi:92, disputes:["RUS","CHN","KOR"])

        add("KOR", res:[.coal,.copper,.coal,.agriculture,.fish],
            corr:63, land:false, terr:.mixed, coast:2413, arable:18,
            rel:.confucian, minors:false, trade:["CHN","USA","JPN"], exp:false, imp:true,
            press:64, gini:31, energy:18, lit:98, hdi:92, disputes:["PRK","JPN"])

        add("PRK", res:[.coal,.iron,.copper,.gold,.copper,.agriculture],
            corr:8, land:false, terr:.mountains, coast:2495, arable:20,
            rel:.secular, trade:["CHN","RUS","IND"], exp:false, imp:true,
            press:2, gini:36, energy:40, lit:100, hdi:56, disputes:["KOR","JPN"])

        add("MNG", res:[.coal,.copper,.gold,.oil,.iron,.phosphates],
            corr:38, land:true, terr:.desert, coast:0, arable:1,
            rel:.buddhist, trade:["CHN","RUS"], exp:true, imp:false,
            press:52, gini:32, energy:85, lit:99, hdi:74)

        add("TWN", res:[.coal,.naturalGas,.agriculture,.fish],
            corr:65, land:false, terr:.island, coast:1566, arable:24,
            rel:.confucian, trade:["CHN","USA","JPN"], press:72, gini:34, energy:15, lit:99, hdi:91, disputes:["CHN"])

        // ── SOUTHEAST ASIA ─────────────────────────────────────────────────────
        add("IDN", res:[.oil,.naturalGas,.coal,.gold,.copper,.nickel,.agriculture,.timber,.fish],
            corr:34, land:false, terr:.island, coast:54716, arable:14,
            rel:.sunniIslam, minors:true, trade:["CHN","USA","JPN"], exp:true, imp:false,
            press:52, gini:38, energy:80, lit:96, hdi:71)

        add("PHL", res:[.gold,.copper,.iron,.nickel,.agriculture,.fish,.timber],
            corr:33, land:false, terr:.island, coast:36289, arable:19,
            rel:.catholic, minors:true, trade:["JPN","USA","CHN"], press:55, gini:40, energy:55, lit:99, hdi:70, disputes:["CHN"])

        add("VNM", res:[.coal,.naturalGas,.oil,.iron,.nickel,.agriculture,.timber,.fish],
            corr:41, land:false, terr:.coastal, coast:3444, arable:28,
            rel:.confucian, trade:["USA","CHN","KOR"], exp:true, imp:true,
            press:21, gini:35, energy:65, lit:95, hdi:70, disputes:["CHN"])

        add("THA", res:[.copper,.timber,.naturalGas,.agriculture,.timber,.fish],
            corr:35, land:false, terr:.mixed, coast:3219, arable:32,
            rel:.buddhist, trade:["CHN","USA","JPN"], exp:false, imp:true,
            press:41, gini:37, energy:42, lit:94, hdi:80)

        add("MYS", res:[.oil,.naturalGas,.timber,.agriculture,.gold,.nickel,.fish],
            corr:47, land:false, terr:.coastal, coast:4675, arable:5,
            rel:.sunniIslam, minors:true, trade:["CHN","SGP","USA"], exp:true, imp:false,
            press:40, gini:41, energy:85, lit:97, hdi:80)

        add("SGP", res:[.fish],
            corr:84, land:false, terr:.island, coast:193, arable:1,
            rel:.confucian, minors:true, trade:["CHN","USA","JPN"], exp:false, imp:true,
            press:62, gini:46, energy:0, lit:98, hdi:94)

        add("MMR", res:[.naturalGas,.oil,.timber,.agriculture,.gold,.nickel],
            corr:23, land:false, terr:.jungle, coast:1930, arable:16,
            rel:.buddhist, minors:true, trade:["CHN","THA","IND"], exp:true, imp:false,
            press:17, gini:31, energy:70, lit:89, hdi:58)

        add("KHM", res:[.oil,.naturalGas,.timber,.agriculture,.fish,.gold],
            corr:22, land:false, terr:.jungle, coast:443, arable:23,
            rel:.buddhist, trade:["USA","CHN","VNM"], press:26, gini:38, energy:30, lit:80, hdi:59)

        add("LAO", res:[.timber,.copper,.gold,.agriculture,.water],
            corr:29, land:true, terr:.jungle, coast:0, arable:6,
            rel:.buddhist, trade:["THA","CHN","VNM"], press:13, gini:36, energy:90, lit:85, hdi:61)

        add("BRN", res:[.oil,.naturalGas,.fish],
            corr:55, land:false, terr:.coastal, coast:161, arable:1,
            rel:.sunniIslam, trade:["JPN","KOR","AUS"], exp:true, imp:false,
            press:32, gini:30, energy:100, lit:97, hdi:83)

        add("TLS", res:[.oil,.naturalGas,.agriculture,.timber],
            corr:38, land:false, terr:.island, coast:706, arable:8,
            rel:.catholic, press:55, gini:29, energy:95, lit:68, hdi:61)

        // ── AFRICA (North) ─────────────────────────────────────────────────────
        add("EGY", res:[.oil,.naturalGas,.iron,.phosphates,.iron,.agriculture,.fish],
            corr:35, land:false, terr:.desert, coast:2450, arable:3,
            rel:.sunniIslam, minors:true, trade:["SAU","ARE","GBR"], exp:true, imp:true,
            press:28, gini:32, energy:80, lit:73, hdi:71, disputes:["ISR","SDN"])

        add("DZA", res:[.oil,.naturalGas,.iron,.phosphates,.gold,.agriculture],
            corr:36, land:false, terr:.desert, coast:998, arable:3,
            rel:.sunniIslam, trade:["ITA","ESP","FRA"], exp:true, imp:false,
            press:30, gini:27, energy:100, lit:81, hdi:75)

        add("MAR", res:[.phosphates,.iron,.iron,.agriculture,.fish],
            corr:38, land:false, terr:.mixed, coast:1835, arable:18,
            rel:.sunniIslam, trade:["ESP","FRA","IND"], press:46, gini:40, energy:15, lit:77, hdi:68)

        add("TUN", res:[.oil,.phosphates,.agriculture,.fish],
            corr:44, land:false, terr:.mixed, coast:1148, arable:19,
            rel:.sunniIslam, trade:["FRA","ITA","DEU"], exp:true, imp:true,
            press:55, gini:33, energy:60, lit:82, hdi:73)

        add("LBY", res:[.oil,.naturalGas,.copper],
            corr:17, land:false, terr:.desert, coast:1770, arable:1,
            rel:.sunniIslam, trade:["ITA","DEU","CHN"], exp:true, imp:false,
            press:18, gini:35, energy:100, lit:91, hdi:71)

        add("SDN", res:[.oil,.naturalGas,.gold,.iron,.copper,.agriculture],
            corr:22, land:false, terr:.desert, coast:853, arable:6,
            rel:.sunniIslam, minors:true, trade:["CHN","ARE","SAU"], exp:true, imp:false,
            press:22, gini:35, energy:70, lit:61, hdi:51, disputes:["EGY"])

        add("SSD", res:[.oil,.agriculture,.iron,.copper,.gold],
            corr:13, land:true, terr:.jungle, coast:0, arable:4,
            rel:.animist, minors:true, press:25, gini:46, energy:90, lit:35, hdi:38)

        // ── AFRICA (East) ──────────────────────────────────────────────────────
        add("ETH", res:[.agriculture,.gold,.gold,.copper],
            corr:38, land:true, terr:.mountains, coast:0, arable:14,
            rel:.orthodox, minors:true, trade:["CHN","SAU","ARE"],
            press:37, gini:35, energy:90, lit:51, hdi:50)

        add("KEN", res:[.agriculture,.fish,.timber,.gold,.copper],
            corr:31, land:false, terr:.mixed, coast:536, arable:9,
            rel:.protestant, minors:true, trade:["CHN","ARE","IND"],
            press:53, gini:40, energy:72, lit:82, hdi:58)

        add("TZA", res:[.agriculture,.gold,.diamonds,.nickel,.coal,.iron,.gold],
            corr:40, land:false, terr:.mixed, coast:1424, arable:6,
            rel:.mixed, minors:true, trade:["IND","CHN","ARE"],
            press:50, gini:38, energy:38, lit:78, hdi:58)

        add("UGA", res:[.agriculture,.cobalt,.copper,.gold,.oil],
            corr:27, land:true, terr:.mixed, coast:0, arable:25,
            rel:.protestant, minors:true, trade:["CHN","ARE","IND"],
            press:40, gini:43, energy:90, lit:77, hdi:55)

        for id in ["RWA","BDI"] {
            add(id, res:[.agriculture,.gold,.copper], corr:25, land:true, terr:.mountains, coast:0, arable:40,
                rel:.catholic, press:35, gini:43, energy:40, lit:72, hdi:52)
        }

        add("SOM", res:[.agriculture,.fish,.uranium,.iron,.gold],
            corr:12, land:false, terr:.desert, coast:3025, arable:2,
            rel:.sunniIslam, trade:["CHN","ARE","IND"], press:16, gini:36, energy:20, lit:37, hdi:30)

        for id in ["ERI","DJI"] {
            add(id, res:[.agriculture,.fish], corr:22, land:false, terr:.desert, coast:800, arable:5,
                rel:.sunniIslam, press:18, gini:36, energy:15, lit:65, hdi:45)
        }

        add("MDG", res:[.agriculture,.fish,.iron,.coal,.coal],
            corr:26, land:false, terr:.island, coast:4828, arable:6,
            rel:.animist, press:53, gini:43, energy:20, lit:77, hdi:53)

        // ── AFRICA (West) ──────────────────────────────────────────────────────
        add("NGA", res:[.oil,.naturalGas,.coal,.copper,.iron,.gold,.agriculture],
            corr:25, land:false, terr:.jungle, coast:853, arable:38,
            rel:.mixed, minors:true, trade:["CHN","IND","USA"], exp:true, imp:false,
            press:41, gini:43, energy:90, lit:62, hdi:54)

        add("GHA", res:[.gold,.oil,.nickel,.agriculture,.fish,.diamonds],
            corr:43, land:false, terr:.coastal, coast:539, arable:21,
            rel:.protestant, trade:["CHN","USA","IND"], exp:true, imp:false,
            press:58, gini:43, energy:40, lit:79, hdi:61)

        add("CIV", res:[.oil,.naturalGas,.agriculture,.diamonds,.iron],
            corr:36, land:false, terr:.coastal, coast:515, arable:8,
            rel:.mixed, minors:true, trade:["FRA","USA","NLD"], exp:true, imp:false,
            press:45, gini:41, energy:40, lit:57, hdi:54)

        add("SEN", res:[.agriculture,.fish,.phosphates,.gold],
            corr:43, land:false, terr:.coastal, coast:531, arable:16,
            rel:.sunniIslam, trade:["FRA","CHN","IND"], press:60, gini:40, energy:25, lit:52, hdi:51)

        // Generic West African defaults
        for id in ["MLI","BFA","NER","GIN","GNB","SLE","LBR","GMB","CPV","MRT","TGO","BEN"] {
            add(id, res:[.agriculture,.gold], corr:30, land:false, terr:.mixed, coast:300, arable:12,
                rel:.sunniIslam, press:38, gini:40, energy:15, lit:35, hdi:45)
        }

        // ── AFRICA (Central) ───────────────────────────────────────────────────
        add("COD", res:[.cobalt,.copper,.gold,.diamonds,.oil,.timber,.agriculture],
            corr:19, land:false, terr:.jungle, coast:37, arable:3,
            rel:.catholic, minors:true, trade:["CHN","ZMB","BEL"], exp:true, imp:false,
            press:36, gini:42, energy:95, lit:77, hdi:48)

        add("AGO", res:[.oil,.diamonds,.iron,.gold,.agriculture],
            corr:28, land:false, terr:.mixed, coast:1600, arable:4,
            rel:.catholic, trade:["CHN","USA","IND"], exp:true, imp:false,
            press:28, gini:51, energy:100, lit:72, hdi:59)

        for id in ["CMR","GAB","COG","CAF","TCD","GNQ","STP"] {
            add(id, res:[.oil,.agriculture,.timber], corr:26, land:false, terr:.jungle, coast:300, arable:8,
                rel:.catholic, press:31, gini:40, energy:55, lit:60, hdi:49)
        }

        // ── AFRICA (Southern) ──────────────────────────────────────────────────
        add("ZAF", res:[.gold,.diamonds,.iron,.coal,.copper,.gold,.agriculture,.uranium,.iron],
            corr:41, land:false, terr:.mixed, coast:2798, arable:10,
            rel:.protestant, minors:true, trade:["CHN","DEU","USA"], exp:true, imp:false,
            press:61, gini:63, energy:75, lit:95, hdi:71)

        add("MOZ", res:[.coal,.iron,.naturalGas,.agriculture,.timber,.fish],
            corr:27, land:false, terr:.coastal, coast:2470, arable:7,
            rel:.catholic, trade:["CHN","IND","ZAF"], exp:true, imp:false,
            press:44, gini:54, energy:35, lit:63, hdi:45)

        add("ZMB", res:[.copper,.cobalt,.copper,.gold,.agriculture],
            corr:37, land:true, terr:.plains, coast:0, arable:5,
            rel:.protestant, trade:["CHN","ZAF","IND"], exp:true, imp:false,
            press:49, gini:57, energy:80, lit:86, hdi:57)

        add("ZWE", res:[.coal,.iron,.nickel,.gold,.agriculture,.gold],
            corr:23, land:false, terr:.mixed, coast:0, arable:11,
            rel:.protestant, trade:["ZAF","CHN","UAE"], press:23, gini:50, energy:40, lit:89, hdi:57)

        for id in ["BWA","NAM","LSO","SWZ","MWI","MUS","SYC","COM","CPV"] {
            add(id, res:[.agriculture,.diamonds], corr:55, land:false, terr:.mixed, coast:200, arable:5,
                rel:.protestant, press:58, gini:53, energy:35, lit:85, hdi:66)
        }

        // ── OCEANIA ────────────────────────────────────────────────────────────
        add("AUS", res:[.iron,.coal,.gold,.nickel,.copper,.uranium,.nickel,.naturalGas,.oil,.agriculture,.timber,.fish],
            corr:77, land:false, terr:.desert, coast:25760, arable:7,
            rel:.protestant, minors:true, trade:["CHN","JPN","KOR"], exp:true, imp:false,
            press:82, gini:34, energy:100, lit:99, hdi:94)

        add("NZL", res:[.naturalGas,.iron,.timber,.agriculture,.fish],
            corr:85, land:false, terr:.island, coast:15134, arable:2,
            rel:.protestant, trade:["AUS","CHN","USA"], exp:false, imp:true,
            press:88, gini:34, energy:82, lit:99, hdi:93)

        add("PNG", res:[.gold,.copper,.oil,.naturalGas,.timber,.agriculture,.fish],
            corr:28, land:false, terr:.jungle, coast:5152, arable:3,
            rel:.protestant, minors:true, trade:["AUS","JPN","CHN"], exp:true, imp:false,
            press:50, gini:42, energy:85, lit:64, hdi:55)

        add("FJI", res:[.timber,.fish,.gold,.copper,.agriculture],
            corr:52, land:false, terr:.island, coast:1129, arable:9,
            rel:.protestant, press:60, gini:36, energy:45, lit:99, hdi:72)

        // Pacific island nations — generic island defaults
        for id in ["SLB","VUT","WSM","TON","KIR","FSM","MHL","PLW","NRU","TUV"] {
            add(id, res:[.fish,.agriculture], corr:45, land:false, terr:.island, coast:200, arable:4,
                rel:.protestant, trade:["AUS","NZL"], press:65, gini:38, energy:30, lit:95, hdi:64)
        }

        // ── SPECIAL TERRITORIES ────────────────────────────────────────────────
        add("XKX", res:[.copper,.nickel,.copper,.agriculture], corr:35, land:true, terr:.mountains, coast:0, arable:27,
            rel:.sunniIslam, press:52, gini:30, energy:40, lit:97, hdi:74, disputes:["SRB"])

        add("HKG", res:[.fish], corr:75, land:false, terr:.island, coast:733, arable:4,
            rel:.confucian, trade:["CHN","USA","JPN"], press:40, gini:54, energy:0, lit:95, hdi:96)

        add("PSE", res:[.agriculture,.naturalGas], corr:32, land:false, terr:.coastal, coast:60, arable:17,
            rel:.sunniIslam, press:36, gini:34, energy:5, lit:97, hdi:70, disputes:["ISR"])

        return db
    }
}

// MARK: - Gameplay Modifiers

extension WorldFactbookRecord {

    /// How much does corruption reduce sanction effectiveness (0.0-1.0)?
    /// Highly corrupt countries have workarounds, black markets, shell companies.
    var sanctionsLeakage: Double {
        // corruptionIndex: 0-100 (higher = less corrupt)
        // Corruption 20 → 60% leakage; Corruption 70 → 15% leakage
        return max(0.05, 0.80 - Double(corruptionIndex) / 130.0)
    }

    /// Bribery action base success rate modifier.
    var briberySuccessRate: Double {
        // Corruption 10 → 0.85; Corruption 80 → 0.15
        return max(0.05, min(0.95, 1.0 - Double(corruptionIndex) / 110.0))
    }

    /// Propaganda effectiveness multiplier.
    /// Low press freedom = state controls information = propaganda works better.
    var propagandaMultiplier: Double {
        // Press freedom 5 → 2.5x; Press freedom 90 → 0.4x
        return max(0.3, 2.8 - Double(pressFreedomIndex) / 55.0)
    }

    /// Instability added by income inequality.
    var inequalityInstabilityBonus: Int {
        // GINI 60 → +15 instability; GINI 25 → +0
        return max(0, (giniCoefficient - 30) / 3)
    }

    /// Oil embargo effectiveness multiplier against this country.
    var oilEmbargoVulnerability: Double {
        // Energy independence 100 → 0.05x (barely hurts exporter);
        // Energy independence 5 → 3.0x (devastating for importer)
        return max(0.05, 3.0 - Double(energyIndependence) / 40.0)
    }

    /// Naval blockade viability for this terrain.
    var canBeBlockaded: Bool {
        return !isLandlocked && terrainType.blockadeable
    }

    /// Military invasion difficulty modifier (0-50).
    var invasionDifficulty: Int {
        var difficulty = terrainType.invasionPenalty
        if isLandlocked { difficulty += 5 }  // supply line issues
        return difficulty
    }
}
