//
//  WorldCountriesDatabase.swift
//  GTNW
//
//  Complete database of 195 UN member states + major territories
//  All countries with coordinates, capitals, and game-ready stats
//  Rewritten by Jordan Koch on 2026-03-05
//

import Foundation

// MARK: - Country Template

/// Lightweight country record used to build full Country objects.
struct CountryTemplate {
    let id: String
    let name: String
    let flag: String
    let capital: String
    let lat: Double
    let lon: Double
    let region: WorldRegion
    let government: GovernmentType
    let alignment: PoliticalAlignment
    let gdpBillions: Double       // USD billions
    let populationMillions: Double
    let militaryStrength: Int     // 0-100
    let aggressionLevel: Int      // 0-100
    let stability: Int            // 0-100
    let nuclearStatus: NuclearStatus
    let yearEnd: Int?             // nil = still exists

    init(
        _ id: String, _ name: String, flag: String, capital: String,
        lat: Double, lon: Double,
        region: WorldRegion,
        gov: GovernmentType,
        align: PoliticalAlignment,
        gdp: Double, pop: Double,
        mil: Int, aggr: Int = 30, stab: Int = 70,
        nuke: NuclearStatus = .none,
        yearEnd: Int? = nil
    ) {
        self.id = id; self.name = name; self.flag = flag; self.capital = capital
        self.lat = lat; self.lon = lon; self.region = region
        self.government = gov; self.alignment = align
        self.gdpBillions = gdp; self.populationMillions = pop
        self.militaryStrength = mil; self.aggressionLevel = aggr; self.stability = stab
        self.nuclearStatus = nuke; self.yearEnd = yearEnd
    }

    /// Convert to a full Country object usable by the game engine.
    func toCountry() -> Country {
        Country(
            id: id, name: name, code: String(id.prefix(3)).uppercased(), flag: flag,
            capital: capital, region: region,
            lat: lat, lon: lon,
            nuclearStatus: nuclearStatus,
            nuclearWarheads: 0,
            icbmCount: 0,
            submarineLaunchedMissiles: 0,
            bombers: 0,
            militaryStrength: max(1, min(100, militaryStrength)),
            gdp: gdpBillions / 1000.0,
            population: max(1, Int(populationMillions)),   // min 1 to prevent divide-by-zero
            economicStrength: economicStrengthFromGDP(),
            government: government,
            alignment: alignment,
            stability: max(0, min(100, stability)),
            aggressionLevel: max(0, min(100, aggressionLevel))  // use actual value, not default 50
        )
    }

    private func economicStrengthFromGDP() -> Int {
        // Normalize: $25T (USA) = 100, $0.1B = 5
        let normalized = Int((gdpBillions / 30_000.0) * 100.0)
        return max(5, min(100, normalized))
    }
}

// MARK: - World Countries Database

struct WorldCountriesDatabase {

    // MARK: - Get All Countries (current era)

    static func allCountries() -> [CountryTemplate] {
        return northAmerica + centralAmericaCaribbean + southAmerica
             + westernEurope + easternEurope
             + formerSoviet + balkans
             + middleEast + southAsia
             + eastAsia + southeastAsia
             + africa
             + oceania
             + territories
    }

    // MARK: - Era-Filtered Countries

    /// Returns countries appropriate for the given year with historical adjustments.
    static func countriesForYear(_ year: Int) -> [CountryTemplate] {
        var countries = allCountries()

        // Russia / Soviet Union historical accuracy
        // Russian Empire existed until the 1917 Revolution
        // Soviet Union founded December 1922, dissolved December 1991
        let removeSoviet = ["RUS","UKR","BLR","MDA","EST","LVA","LTU",
                            "GEO","ARM","AZE","KAZ","UZB","TKM","KGZ","TJK"]
        if year < 1917 {
            // Pre-revolutionary Russia: Tsarist Russian Empire
            countries.removeAll { removeSoviet.contains($0.id) }
            countries.append(russianEmpire(year: year))
        } else if year < 1922 {
            // Revolutionary / Civil War period: just "Russia"
            countries.removeAll { removeSoviet.contains($0.id) }
            countries.append(revolutionaryRussia())
        } else if year < 1991 {
            // Soviet Union era
            countries.removeAll { removeSoviet.contains($0.id) }
            countries.append(ussr(year: year))
        }
        // Post-1991: individual successor states already in allCountries()

        // Germany — name and form changed significantly across eras
        if year < 1871 {
            // Pre-unification: German Confederation / Prussia dominates
            countries.removeAll { $0.id == "DEU" }
            countries.append(germanConfederation(year: year))
        } else if year < 1918 {
            // Wilhelmine German Empire (unified 1871, dissolved 1918)
            countries.removeAll { $0.id == "DEU" }
            countries.append(germanEmpire(year: year))
        } else if year < 1933 {
            // Weimar Republic (1918-1933)
            countries.removeAll { $0.id == "DEU" }
            countries.append(weimarGermany(year: year))
        } else if year < 1945 {
            // Nazi Germany / Third Reich (1933-1945)
            countries.removeAll { $0.id == "DEU" }
            countries.append(naziGermany(year: year))
        } else if year < 1990 {
            // Post-WWII split: West Germany + East Germany
            countries.removeAll { $0.id == "DEU" }
            countries.append(westGermany(year: year))
            countries.append(eastGermany(year: year))
        }
        // 1990+: unified Germany (DEU) stays from allCountries()

        // Yugoslavia: unified until 1992
        if year < 1992 {
            let removeYugo = ["SRB","HRV","BIH","SVN","MKD","MNE","XKX"]
            countries.removeAll { removeYugo.contains($0.id) }
            countries.append(yugoslavia())
        }

        // Czechoslovakia: unified until 1993
        if year < 1993 {
            countries.removeAll { ["CZE","SVK"].contains($0.id) }
            countries.append(czechoslovakia())
        }

        // Vietnam: only split during the actual North/South period (1954-1975)
        // Before 1954: unified Vietnam/French Indochina/Nguyen Dynasty
        // After 1975: reunified Socialist Republic of Vietnam
        if year >= 1954 && year < 1975 {
            countries.removeAll { $0.id == "VNM" }
            countries.append(northVietnam())
            countries.append(southVietnam())
        }
        // Before 1954 or after 1975: VNM stays as unified Vietnam

        // Korea: always split (never unified)
        // North/South Korea always separate — already in allCountries()

        // China: Taiwan situation — Taiwan not recognized by most
        // Taiwan is included as a territory always

        // Israel didn't exist before 1948
        if year < 1948 {
            countries.removeAll { $0.id == "ISR" }
        }

        // Bangladesh: independent from 1971
        if year < 1971 {
            countries.removeAll { $0.id == "BGD" }
        }

        // Saudi Arabia: unified Kingdom founded 1932
        if year < 1932 {
            countries.removeAll { $0.id == "SAU" }
        }

        // South Korea: established 1945 after Japanese surrender
        if year < 1945 {
            countries.removeAll { $0.id == "KOR" }
        }

        // North Korea: established 1948 after Soviet occupation
        if year < 1948 {
            countries.removeAll { $0.id == "PRK" }
        }

        // Singapore: independent 1965
        if year < 1965 {
            countries.removeAll { $0.id == "SGP" }
        }

        // UAE: independent 1971
        if year < 1971 {
            countries.removeAll { $0.id == "ARE" }
        }

        // Qatar, Bahrain, Kuwait: independent ~1971
        if year < 1971 {
            countries.removeAll { ["QAT","BHR","KWT"].contains($0.id) }
        }

        // Pakistan: independent 1947 (partition of India)
        if year < 1947 {
            countries.removeAll { $0.id == "PAK" }
        }

        // Jordan (Transjordan): independent 1946
        if year < 1946 {
            countries.removeAll { $0.id == "JOR" }
        }

        // Many African nations gained independence ~1960
        // Remove the most historically significant absences before 1960
        if year < 1960 {
            let postColonialAfrica = ["NGA","ETH","KEN","TZA","GHA","CIV","SEN","CMR",
                                      "ZMB","ZWE","MOZ","AGO","COD","COG","GAB","CAF",
                                      "TCD","MLI","BFA","NER","GIN","GNB","SLE","LBR",
                                      "GMB","TGO","BEN","RWA","BDI","SSD","ERI","DJI",
                                      "SOM","UGA","MDG","MUS","SYC","COM","CPV","STP",
                                      "NAM","BWA","LSO","SWZ","MWI"]
            countries.removeAll { postColonialAfrica.contains($0.id) }
        }

        // Timor-Leste: independent 2002
        if year < 2002 {
            countries.removeAll { $0.id == "TLS" }
        }

        // Kosovo: declared independence 2008
        if year < 2008 {
            countries.removeAll { $0.id == "XKX" }
        }

        // NOTE: Nuclear status cleanup is handled in GameState.adjustCountriesForEra()
        // after conversion to Country objects, where direct mutation is safe.

        // Many African nations gained independence 1960s
        // Remove not-yet-independent nations
        countries = countries.filter { c in
            guard let end = c.yearEnd else { return true }
            return year <= end
        }

        return countries
    }

    // MARK: - North America

    static let northAmerica: [CountryTemplate] = [
        CountryTemplate("USA","United States",flag:"🇺🇸",capital:"Washington D.C.",
            lat:38.9072,lon:-77.0369,region:.northAmerica,gov:.republic,align:.western,
            gdp:27000,pop:335,mil:100,aggr:60,stab:80,nuke:.declared),
        CountryTemplate("CAN","Canada",flag:"🇨🇦",capital:"Ottawa",
            lat:45.4215,lon:-75.6972,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:2200,pop:40,mil:55,aggr:20,stab:95),
        CountryTemplate("MEX","Mexico",flag:"🇲🇽",capital:"Mexico City",
            lat:19.4326,lon:-99.1332,region:.northAmerica,gov:.republic,align:.western,
            gdp:1800,pop:130,mil:50,aggr:25,stab:65),
    ]

    // MARK: - Central America & Caribbean

    static let centralAmericaCaribbean: [CountryTemplate] = [
        CountryTemplate("GTM","Guatemala",flag:"🇬🇹",capital:"Guatemala City",
            lat:14.6349,lon:-90.5069,region:.northAmerica,gov:.republic,align:.western,
            gdp:100,pop:18,mil:30,aggr:35,stab:55),
        CountryTemplate("HND","Honduras",flag:"🇭🇳",capital:"Tegucigalpa",
            lat:14.0723,lon:-87.2057,region:.northAmerica,gov:.republic,align:.western,
            gdp:32,pop:10,mil:25,aggr:30,stab:50),
        CountryTemplate("SLV","El Salvador",flag:"🇸🇻",capital:"San Salvador",
            lat:13.6929,lon:-89.2182,region:.northAmerica,gov:.republic,align:.western,
            gdp:35,pop:6,mil:25,aggr:35,stab:55),
        CountryTemplate("NIC","Nicaragua",flag:"🇳🇮",capital:"Managua",
            lat:12.1328,lon:-86.2504,region:.northAmerica,gov:.authoritarian,align:.eastern,
            gdp:17,pop:7,mil:30,aggr:50,stab:45),
        CountryTemplate("CRI","Costa Rica",flag:"🇨🇷",capital:"San José",
            lat:9.9281,lon:-84.0907,region:.northAmerica,gov:.republic,align:.western,
            gdp:70,pop:5,mil:10,aggr:10,stab:88),
        CountryTemplate("PAN","Panama",flag:"🇵🇦",capital:"Panama City",
            lat:8.9936,lon:-79.5197,region:.northAmerica,gov:.republic,align:.western,
            gdp:80,pop:4,mil:20,aggr:20,stab:72),
        CountryTemplate("BLZ","Belize",flag:"🇧🇿",capital:"Belmopan",
            lat:17.2534,lon:-88.7713,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:3,pop:0.4,mil:10,aggr:10,stab:70),
        CountryTemplate("CUB","Cuba",flag:"🇨🇺",capital:"Havana",
            lat:23.1136,lon:-82.3666,region:.northAmerica,gov:.communist,align:.eastern,
            gdp:100,pop:11,mil:40,aggr:60,stab:60),
        CountryTemplate("DOM","Dominican Republic",flag:"🇩🇴",capital:"Santo Domingo",
            lat:18.4861,lon:-69.9312,region:.northAmerica,gov:.republic,align:.western,
            gdp:120,pop:11,mil:25,aggr:25,stab:65),
        CountryTemplate("HTI","Haiti",flag:"🇭🇹",capital:"Port-au-Prince",
            lat:18.5944,lon:-72.3074,region:.northAmerica,gov:.republic,align:.nonAligned,
            gdp:22,pop:12,mil:15,aggr:30,stab:25),
        CountryTemplate("JAM","Jamaica",flag:"🇯🇲",capital:"Kingston",
            lat:17.9970,lon:-76.7936,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:18,pop:3,mil:15,aggr:15,stab:68),
        CountryTemplate("TTO","Trinidad and Tobago",flag:"🇹🇹",capital:"Port of Spain",
            lat:10.6549,lon:-61.5019,region:.northAmerica,gov:.republic,align:.western,
            gdp:27,pop:1.4,mil:20,aggr:15,stab:72),
        CountryTemplate("BRB","Barbados",flag:"🇧🇧",capital:"Bridgetown",
            lat:13.1132,lon:-59.5988,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:6,pop:0.3,mil:5,aggr:5,stab:85),
        CountryTemplate("LCA","Saint Lucia",flag:"🇱🇨",capital:"Castries",
            lat:13.9094,lon:-60.9789,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:2,pop:0.2,mil:3,aggr:5,stab:80),
        CountryTemplate("VCT","St. Vincent & Grenadines",flag:"🇻🇨",capital:"Kingstown",
            lat:13.1600,lon:-61.2248,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:1,pop:0.1,mil:2,aggr:5,stab:80),
        CountryTemplate("GRD","Grenada",flag:"🇬🇩",capital:"St. George's",
            lat:12.1165,lon:-61.6790,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:1,pop:0.1,mil:2,aggr:5,stab:80),
        CountryTemplate("ATG","Antigua and Barbuda",flag:"🇦🇬",capital:"Saint John's",
            lat:17.1274,lon:-61.8468,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:2,pop:0.1,mil:2,aggr:5,stab:80),
        CountryTemplate("KNA","St. Kitts and Nevis",flag:"🇰🇳",capital:"Basseterre",
            lat:17.3578,lon:-62.7830,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:1,pop:0.05,mil:2,aggr:5,stab:80),
        CountryTemplate("DMA","Dominica",flag:"🇩🇲",capital:"Roseau",
            lat:15.3092,lon:-61.3794,region:.northAmerica,gov:.republic,align:.western,
            gdp:1,pop:0.07,mil:2,aggr:5,stab:78),
        CountryTemplate("BHS","The Bahamas",flag:"🇧🇸",capital:"Nassau",
            lat:25.0480,lon:-77.3554,region:.northAmerica,gov:.monarchy,align:.western,
            gdp:15,pop:0.4,mil:5,aggr:5,stab:82),
    ]

    // MARK: - South America

    static let southAmerica: [CountryTemplate] = [
        CountryTemplate("BRA","Brazil",flag:"🇧🇷",capital:"Brasília",
            lat:-15.8267,lon:-47.9218,region:.southAmerica,gov:.republic,align:.nonAligned,
            gdp:2300,pop:216,mil:70,aggr:40,stab:65),
        CountryTemplate("ARG","Argentina",flag:"🇦🇷",capital:"Buenos Aires",
            lat:-34.6037,lon:-58.3816,region:.southAmerica,gov:.republic,align:.western,
            gdp:640,pop:46,mil:50,aggr:35,stab:55),
        CountryTemplate("CHL","Chile",flag:"🇨🇱",capital:"Santiago",
            lat:-33.4489,lon:-70.6693,region:.southAmerica,gov:.republic,align:.western,
            gdp:350,pop:20,mil:45,aggr:25,stab:75),
        CountryTemplate("COL","Colombia",flag:"🇨🇴",capital:"Bogotá",
            lat:4.7110,lon:-74.0721,region:.southAmerica,gov:.republic,align:.western,
            gdp:380,pop:52,mil:50,aggr:45,stab:55),
        CountryTemplate("PER","Peru",flag:"🇵🇪",capital:"Lima",
            lat:-12.0464,lon:-77.0428,region:.southAmerica,gov:.republic,align:.nonAligned,
            gdp:270,pop:34,mil:40,aggr:30,stab:58),
        CountryTemplate("VEN","Venezuela",flag:"🇻🇪",capital:"Caracas",
            lat:10.4806,lon:-66.9036,region:.southAmerica,gov:.authoritarian,align:.eastern,
            gdp:100,pop:28,mil:45,aggr:60,stab:30),
        CountryTemplate("ECU","Ecuador",flag:"🇪🇨",capital:"Quito",
            lat:-0.2295,lon:-78.5243,region:.southAmerica,gov:.republic,align:.nonAligned,
            gdp:120,pop:18,mil:30,aggr:30,stab:55),
        CountryTemplate("BOL","Bolivia",flag:"🇧🇴",capital:"Sucre",
            lat:-19.0196,lon:-65.2619,region:.southAmerica,gov:.republic,align:.nonAligned,
            gdp:48,pop:12,mil:25,aggr:35,stab:52),
        CountryTemplate("PRY","Paraguay",flag:"🇵🇾",capital:"Asunción",
            lat:-25.2867,lon:-57.6470,region:.southAmerica,gov:.republic,align:.western,
            gdp:45,pop:7,mil:20,aggr:25,stab:65),
        CountryTemplate("URY","Uruguay",flag:"🇺🇾",capital:"Montevideo",
            lat:-34.9011,lon:-56.1645,region:.southAmerica,gov:.republic,align:.western,
            gdp:75,pop:3,mil:20,aggr:15,stab:82),
        CountryTemplate("GUY","Guyana",flag:"🇬🇾",capital:"Georgetown",
            lat:6.8013,lon:-58.1551,region:.southAmerica,gov:.republic,align:.nonAligned,
            gdp:16,pop:1,mil:15,aggr:20,stab:65),
        CountryTemplate("SUR","Suriname",flag:"🇸🇷",capital:"Paramaribo",
            lat:5.8520,lon:-55.2038,region:.southAmerica,gov:.republic,align:.nonAligned,
            gdp:5,pop:0.6,mil:10,aggr:15,stab:60),
    ]

    // MARK: - Western Europe

    static let westernEurope: [CountryTemplate] = [
        CountryTemplate("GBR","United Kingdom",flag:"🇬🇧",capital:"London",
            lat:51.5074,lon:-0.1278,region:.europe,gov:.monarchy,align:.western,
            gdp:3500,pop:68,mil:80,aggr:50,stab:82,nuke:.declared),
        CountryTemplate("DEU","Germany",flag:"🇩🇪",capital:"Berlin",
            lat:52.5200,lon:13.4050,region:.europe,gov:.republic,align:.western,
            gdp:4400,pop:84,mil:70,aggr:30,stab:90),
        CountryTemplate("FRA","France",flag:"🇫🇷",capital:"Paris",
            lat:48.8566,lon:2.3522,region:.europe,gov:.republic,align:.western,
            gdp:3000,pop:68,mil:75,aggr:45,stab:80,nuke:.declared),
        CountryTemplate("ITA","Italy",flag:"🇮🇹",capital:"Rome",
            lat:41.9028,lon:12.4964,region:.europe,gov:.republic,align:.western,
            gdp:2200,pop:59,mil:60,aggr:30,stab:72),
        CountryTemplate("ESP","Spain",flag:"🇪🇸",capital:"Madrid",
            lat:40.4168,lon:-3.7038,region:.europe,gov:.monarchy,align:.western,
            gdp:1600,pop:48,mil:55,aggr:25,stab:80),
        CountryTemplate("NLD","Netherlands",flag:"🇳🇱",capital:"Amsterdam",
            lat:52.3676,lon:4.9041,region:.europe,gov:.monarchy,align:.western,
            gdp:1100,pop:18,mil:50,aggr:20,stab:92),
        CountryTemplate("BEL","Belgium",flag:"🇧🇪",capital:"Brussels",
            lat:50.8503,lon:4.3517,region:.europe,gov:.monarchy,align:.western,
            gdp:630,pop:12,mil:45,aggr:15,stab:80),
        CountryTemplate("CHE","Switzerland",flag:"🇨🇭",capital:"Bern",
            lat:46.9480,lon:7.4474,region:.europe,gov:.republic,align:.nonAligned,
            gdp:900,pop:9,mil:40,aggr:5,stab:98),
        CountryTemplate("AUT","Austria",flag:"🇦🇹",capital:"Vienna",
            lat:48.2082,lon:16.3738,region:.europe,gov:.republic,align:.western,
            gdp:540,pop:9,mil:35,aggr:10,stab:92),
        CountryTemplate("SWE","Sweden",flag:"🇸🇪",capital:"Stockholm",
            lat:59.3293,lon:18.0686,region:.europe,gov:.monarchy,align:.western,
            gdp:630,pop:11,mil:45,aggr:15,stab:95),
        CountryTemplate("NOR","Norway",flag:"🇳🇴",capital:"Oslo",
            lat:59.9139,lon:10.7522,region:.europe,gov:.monarchy,align:.western,
            gdp:580,pop:6,mil:40,aggr:20,stab:96),
        CountryTemplate("DNK","Denmark",flag:"🇩🇰",capital:"Copenhagen",
            lat:55.6761,lon:12.5683,region:.europe,gov:.monarchy,align:.western,
            gdp:410,pop:6,mil:35,aggr:15,stab:96),
        CountryTemplate("FIN","Finland",flag:"🇫🇮",capital:"Helsinki",
            lat:60.1695,lon:24.9354,region:.europe,gov:.republic,align:.western,
            gdp:300,pop:6,mil:45,aggr:20,stab:94),
        CountryTemplate("IRL","Ireland",flag:"🇮🇪",capital:"Dublin",
            lat:53.3498,lon:-6.2603,region:.europe,gov:.republic,align:.western,
            gdp:600,pop:5,mil:25,aggr:10,stab:90),
        CountryTemplate("PRT","Portugal",flag:"🇵🇹",capital:"Lisbon",
            lat:38.7223,lon:-9.1393,region:.europe,gov:.republic,align:.western,
            gdp:280,pop:10,mil:35,aggr:20,stab:82),
        CountryTemplate("GRC","Greece",flag:"🇬🇷",capital:"Athens",
            lat:37.9838,lon:23.7275,region:.europe,gov:.republic,align:.western,
            gdp:240,pop:10,mil:50,aggr:40,stab:68),
        CountryTemplate("ISL","Iceland",flag:"🇮🇸",capital:"Reykjavík",
            lat:64.1355,lon:-21.8954,region:.europe,gov:.republic,align:.western,
            gdp:28,pop:0.4,mil:5,aggr:5,stab:98),
        CountryTemplate("LUX","Luxembourg",flag:"🇱🇺",capital:"Luxembourg City",
            lat:49.6117,lon:6.1319,region:.europe,gov:.monarchy,align:.western,
            gdp:90,pop:0.7,mil:10,aggr:5,stab:96),
        CountryTemplate("MCO","Monaco",flag:"🇲🇨",capital:"Monaco",
            lat:43.7384,lon:7.4246,region:.europe,gov:.monarchy,align:.western,
            gdp:7,pop:0.04,mil:0,aggr:2,stab:98),
        CountryTemplate("AND","Andorra",flag:"🇦🇩",capital:"Andorra la Vella",
            lat:42.5078,lon:1.5211,region:.europe,gov:.monarchy,align:.western,
            gdp:3,pop:0.08,mil:0,aggr:2,stab:95),
        CountryTemplate("LIE","Liechtenstein",flag:"🇱🇮",capital:"Vaduz",
            lat:47.1410,lon:9.5209,region:.europe,gov:.monarchy,align:.western,
            gdp:7,pop:0.04,mil:0,aggr:2,stab:98),
        CountryTemplate("SMR","San Marino",flag:"🇸🇲",capital:"San Marino",
            lat:43.9424,lon:12.4578,region:.europe,gov:.republic,align:.western,
            gdp:2,pop:0.03,mil:0,aggr:2,stab:96),
        CountryTemplate("VAT","Vatican City",flag:"🇻🇦",capital:"Vatican City",
            lat:41.9029,lon:12.4534,region:.europe,gov:.theocracy,align:.nonAligned,
            gdp:0.5,pop:0.001,mil:0,aggr:0,stab:99),
        CountryTemplate("MLT","Malta",flag:"🇲🇹",capital:"Valletta",
            lat:35.8997,lon:14.5147,region:.europe,gov:.republic,align:.western,
            gdp:17,pop:0.5,mil:5,aggr:5,stab:88),
        CountryTemplate("CYP","Cyprus",flag:"🇨🇾",capital:"Nicosia",
            lat:35.1856,lon:33.3823,region:.europe,gov:.republic,align:.western,
            gdp:28,pop:1.2,mil:10,aggr:20,stab:72),
    ]

    // MARK: - Eastern Europe

    static let easternEurope: [CountryTemplate] = [
        CountryTemplate("POL","Poland",flag:"🇵🇱",capital:"Warsaw",
            lat:52.2297,lon:21.0122,region:.europe,gov:.republic,align:.western,
            gdp:780,pop:38,mil:65,aggr:30,stab:80),
        CountryTemplate("ROU","Romania",flag:"🇷🇴",capital:"Bucharest",
            lat:44.4268,lon:26.1025,region:.europe,gov:.republic,align:.western,
            gdp:350,pop:19,mil:45,aggr:30,stab:70),
        CountryTemplate("CZE","Czech Republic",flag:"🇨🇿",capital:"Prague",
            lat:50.0755,lon:14.4378,region:.europe,gov:.republic,align:.western,
            gdp:330,pop:11,mil:40,aggr:20,stab:82),
        CountryTemplate("HUN","Hungary",flag:"🇭🇺",capital:"Budapest",
            lat:47.4979,lon:19.0402,region:.europe,gov:.republic,align:.western,
            gdp:210,pop:10,mil:35,aggr:25,stab:72),
        CountryTemplate("SVK","Slovakia",flag:"🇸🇰",capital:"Bratislava",
            lat:48.1486,lon:17.1077,region:.europe,gov:.republic,align:.western,
            gdp:130,pop:5,mil:30,aggr:20,stab:78),
        CountryTemplate("BGR","Bulgaria",flag:"🇧🇬",capital:"Sofia",
            lat:42.6977,lon:23.3219,region:.europe,gov:.republic,align:.western,
            gdp:100,pop:7,mil:35,aggr:25,stab:68),
        CountryTemplate("UKR","Ukraine",flag:"🇺🇦",capital:"Kyiv",
            lat:50.4501,lon:30.5234,region:.europe,gov:.republic,align:.western,
            gdp:200,pop:41,mil:70,aggr:45,stab:45),
        CountryTemplate("BLR","Belarus",flag:"🇧🇾",capital:"Minsk",
            lat:53.9045,lon:27.5615,region:.europe,gov:.authoritarian,align:.eastern,
            gdp:75,pop:9,mil:50,aggr:60,stab:55),
        CountryTemplate("MDA","Moldova",flag:"🇲🇩",capital:"Chișinău",
            lat:47.0105,lon:28.8638,region:.europe,gov:.republic,align:.nonAligned,
            gdp:18,pop:3,mil:15,aggr:25,stab:55),
        CountryTemplate("LTU","Lithuania",flag:"🇱🇹",capital:"Vilnius",
            lat:54.6872,lon:25.2797,region:.europe,gov:.republic,align:.western,
            gdp:67,pop:3,mil:22,aggr:20,stab:82),
        CountryTemplate("LVA","Latvia",flag:"🇱🇻",capital:"Riga",
            lat:56.9496,lon:24.1052,region:.europe,gov:.republic,align:.western,
            gdp:42,pop:1.9,mil:18,aggr:20,stab:80),
        CountryTemplate("EST","Estonia",flag:"🇪🇪",capital:"Tallinn",
            lat:59.4370,lon:24.7536,region:.europe,gov:.republic,align:.western,
            gdp:38,pop:1.3,mil:20,aggr:18,stab:85),
    ]

    // MARK: - Former Soviet (Caucasus + Central Asia)

    static let formerSoviet: [CountryTemplate] = [
        CountryTemplate("RUS","Russian Federation",flag:"🇷🇺",capital:"Moscow",
            lat:55.7558,lon:37.6173,region:.europe,gov:.authoritarian,align:.eastern,
            gdp:2200,pop:144,mil:92,aggr:80,stab:62,nuke:.declared),
        CountryTemplate("GEO","Georgia",flag:"🇬🇪",capital:"Tbilisi",
            lat:41.6941,lon:44.8337,region:.asia,gov:.republic,align:.western,
            gdp:24,pop:3.7,mil:20,aggr:35,stab:62),
        CountryTemplate("ARM","Armenia",flag:"🇦🇲",capital:"Yerevan",
            lat:40.1811,lon:44.5136,region:.asia,gov:.republic,align:.eastern,
            gdp:19,pop:3,mil:25,aggr:40,stab:58),
        CountryTemplate("AZE","Azerbaijan",flag:"🇦🇿",capital:"Baku",
            lat:40.4093,lon:49.8671,region:.asia,gov:.authoritarian,align:.nonAligned,
            gdp:55,pop:10,mil:42,aggr:50,stab:62),
        CountryTemplate("KAZ","Kazakhstan",flag:"🇰🇿",capital:"Astana",
            lat:51.1694,lon:71.4491,region:.asia,gov:.authoritarian,align:.eastern,
            gdp:260,pop:20,mil:48,aggr:35,stab:65),
        CountryTemplate("UZB","Uzbekistan",flag:"🇺🇿",capital:"Tashkent",
            lat:41.2995,lon:69.2401,region:.asia,gov:.authoritarian,align:.eastern,
            gdp:90,pop:36,mil:40,aggr:35,stab:62),
        CountryTemplate("TKM","Turkmenistan",flag:"🇹🇲",capital:"Ashgabat",
            lat:37.9601,lon:58.3261,region:.asia,gov:.authoritarian,align:.eastern,
            gdp:55,pop:6,mil:30,aggr:30,stab:55),
        CountryTemplate("KGZ","Kyrgyzstan",flag:"🇰🇬",capital:"Bishkek",
            lat:42.8746,lon:74.5698,region:.asia,gov:.republic,align:.nonAligned,
            gdp:12,pop:7,mil:25,aggr:30,stab:55),
        CountryTemplate("TJK","Tajikistan",flag:"🇹🇯",capital:"Dushanbe",
            lat:38.5598,lon:68.7739,region:.asia,gov:.authoritarian,align:.eastern,
            gdp:12,pop:10,mil:25,aggr:35,stab:50),
    ]

    // MARK: - Balkans

    static let balkans: [CountryTemplate] = [
        CountryTemplate("SRB","Serbia",flag:"🇷🇸",capital:"Belgrade",
            lat:44.8176,lon:20.4569,region:.europe,gov:.republic,align:.nonAligned,
            gdp:75,pop:7,mil:42,aggr:45,stab:62),
        CountryTemplate("HRV","Croatia",flag:"🇭🇷",capital:"Zagreb",
            lat:45.8150,lon:15.9819,region:.europe,gov:.republic,align:.western,
            gdp:80,pop:4,mil:30,aggr:30,stab:72),
        CountryTemplate("BIH","Bosnia and Herzegovina",flag:"🇧🇦",capital:"Sarajevo",
            lat:43.8563,lon:18.4131,region:.europe,gov:.republic,align:.nonAligned,
            gdp:25,pop:3,mil:25,aggr:35,stab:52),
        CountryTemplate("SVN","Slovenia",flag:"🇸🇮",capital:"Ljubljana",
            lat:46.0569,lon:14.5058,region:.europe,gov:.republic,align:.western,
            gdp:70,pop:2,mil:25,aggr:15,stab:85),
        CountryTemplate("MKD","North Macedonia",flag:"🇲🇰",capital:"Skopje",
            lat:41.9965,lon:21.4314,region:.europe,gov:.republic,align:.western,
            gdp:15,pop:2,mil:20,aggr:25,stab:65),
        CountryTemplate("MNE","Montenegro",flag:"🇲🇪",capital:"Podgorica",
            lat:42.4304,lon:19.2594,region:.europe,gov:.republic,align:.western,
            gdp:7,pop:0.6,mil:15,aggr:20,stab:68),
        CountryTemplate("ALB","Albania",flag:"🇦🇱",capital:"Tirana",
            lat:41.3275,lon:19.8187,region:.europe,gov:.republic,align:.western,
            gdp:22,pop:3,mil:20,aggr:30,stab:62),
    ]

    // MARK: - Middle East

    static let middleEast: [CountryTemplate] = [
        CountryTemplate("SAU","Saudi Arabia",flag:"🇸🇦",capital:"Riyadh",
            lat:24.7136,lon:46.6753,region:.middleEast,gov:.monarchy,align:.western,
            gdp:1100,pop:36,mil:72,aggr:50,stab:65,nuke:.suspected),
        CountryTemplate("IRN","Iran",flag:"🇮🇷",capital:"Tehran",
            lat:35.6892,lon:51.3890,region:.middleEast,gov:.theocracy,align:.independent,
            gdp:400,pop:89,mil:72,aggr:75,stab:58,nuke:.developing),
        CountryTemplate("ISR","Israel",flag:"🇮🇱",capital:"Jerusalem",
            lat:31.7683,lon:35.2137,region:.middleEast,gov:.republic,align:.western,
            gdp:550,pop:9,mil:90,aggr:70,stab:72,nuke:.undeclared),
        CountryTemplate("TUR","Turkey",flag:"🇹🇷",capital:"Ankara",
            lat:39.9334,lon:32.8597,region:.middleEast,gov:.republic,align:.western,
            gdp:1100,pop:86,mil:78,aggr:55,stab:60),
        CountryTemplate("ARE","United Arab Emirates",flag:"🇦🇪",capital:"Abu Dhabi",
            lat:24.4539,lon:54.3773,region:.middleEast,gov:.monarchy,align:.western,
            gdp:530,pop:10,mil:62,aggr:40,stab:72),
        CountryTemplate("IRQ","Iraq",flag:"🇮🇶",capital:"Baghdad",
            lat:33.3152,lon:44.3661,region:.middleEast,gov:.republic,align:.nonAligned,
            gdp:260,pop:45,mil:48,aggr:55,stab:42),
        CountryTemplate("SYR","Syria",flag:"🇸🇾",capital:"Damascus",
            lat:33.5102,lon:36.2913,region:.middleEast,gov:.authoritarian,align:.eastern,
            gdp:40,pop:23,mil:42,aggr:60,stab:25),
        CountryTemplate("JOR","Jordan",flag:"🇯🇴",capital:"Amman",
            lat:31.9522,lon:35.9334,region:.middleEast,gov:.monarchy,align:.western,
            gdp:52,pop:11,mil:48,aggr:30,stab:65),
        CountryTemplate("LBN","Lebanon",flag:"🇱🇧",capital:"Beirut",
            lat:33.8938,lon:35.5018,region:.middleEast,gov:.republic,align:.nonAligned,
            gdp:20,pop:5,mil:25,aggr:40,stab:28),
        CountryTemplate("YEM","Yemen",flag:"🇾🇪",capital:"Sana'a",
            lat:15.3694,lon:44.1910,region:.middleEast,gov:.republic,align:.nonAligned,
            gdp:22,pop:34,mil:30,aggr:60,stab:15),
        CountryTemplate("OMN","Oman",flag:"🇴🇲",capital:"Muscat",
            lat:23.5880,lon:58.3829,region:.middleEast,gov:.monarchy,align:.western,
            gdp:115,pop:5,mil:48,aggr:25,stab:72),
        CountryTemplate("KWT","Kuwait",flag:"🇰🇼",capital:"Kuwait City",
            lat:29.3759,lon:47.9774,region:.middleEast,gov:.monarchy,align:.western,
            gdp:165,pop:5,mil:42,aggr:20,stab:72),
        CountryTemplate("QAT","Qatar",flag:"🇶🇦",capital:"Doha",
            lat:25.2854,lon:51.5310,region:.middleEast,gov:.monarchy,align:.western,
            gdp:240,pop:3,mil:38,aggr:20,stab:78),
        CountryTemplate("BHR","Bahrain",flag:"🇧🇭",capital:"Manama",
            lat:26.0667,lon:50.5577,region:.middleEast,gov:.monarchy,align:.western,
            gdp:45,pop:2,mil:30,aggr:25,stab:65),
        CountryTemplate("PSE","Palestine",flag:"🇵🇸",capital:"Ramallah",
            lat:31.9522,lon:35.2332,region:.middleEast,gov:.republic,align:.nonAligned,
            gdp:20,pop:5,mil:15,aggr:70,stab:25),
    ]

    // MARK: - South Asia

    static let southAsia: [CountryTemplate] = [
        CountryTemplate("IND","India",flag:"🇮🇳",capital:"New Delhi",
            lat:28.6139,lon:77.2090,region:.asia,gov:.republic,align:.nonAligned,
            gdp:3500,pop:1429,mil:85,aggr:35,stab:72,nuke:.declared),
        CountryTemplate("PAK","Pakistan",flag:"🇵🇰",capital:"Islamabad",
            lat:33.6844,lon:73.0479,region:.asia,gov:.republic,align:.nonAligned,
            gdp:380,pop:225,mil:72,aggr:60,stab:45,nuke:.declared),
        CountryTemplate("BGD","Bangladesh",flag:"🇧🇩",capital:"Dhaka",
            lat:23.8103,lon:90.4125,region:.asia,gov:.republic,align:.nonAligned,
            gdp:460,pop:173,mil:42,aggr:25,stab:55),
        CountryTemplate("AFG","Afghanistan",flag:"🇦🇫",capital:"Kabul",
            lat:34.5553,lon:69.2075,region:.asia,gov:.authoritarian,align:.nonAligned,
            gdp:20,pop:42,mil:45,aggr:70,stab:20),
        CountryTemplate("LKA","Sri Lanka",flag:"🇱🇰",capital:"Sri Jayawardenepura Kotte",
            lat:6.9271,lon:79.8612,region:.asia,gov:.republic,align:.nonAligned,
            gdp:95,pop:23,mil:35,aggr:30,stab:55),
        CountryTemplate("NPL","Nepal",flag:"🇳🇵",capital:"Kathmandu",
            lat:27.7172,lon:85.3240,region:.asia,gov:.republic,align:.nonAligned,
            gdp:42,pop:31,mil:25,aggr:15,stab:58),
        CountryTemplate("BTN","Bhutan",flag:"🇧🇹",capital:"Thimphu",
            lat:27.4716,lon:89.6386,region:.asia,gov:.monarchy,align:.nonAligned,
            gdp:3,pop:0.8,mil:10,aggr:8,stab:80),
        CountryTemplate("MDV","Maldives",flag:"🇲🇻",capital:"Malé",
            lat:4.1755,lon:73.5093,region:.asia,gov:.republic,align:.nonAligned,
            gdp:6,pop:0.5,mil:5,aggr:8,stab:70),
    ]

    // MARK: - East Asia

    static let eastAsia: [CountryTemplate] = [
        CountryTemplate("CHN","People's Republic of China",flag:"🇨🇳",capital:"Beijing",
            lat:39.9042,lon:116.4074,region:.asia,gov:.communist,align:.eastern,
            gdp:18000,pop:1425,mil:95,aggr:70,stab:78,nuke:.declared),
        CountryTemplate("JPN","Japan",flag:"🇯🇵",capital:"Tokyo",
            lat:35.6762,lon:139.6503,region:.asia,gov:.monarchy,align:.western,
            gdp:4200,pop:123,mil:68,aggr:20,stab:92),
        CountryTemplate("KOR","South Korea",flag:"🇰🇷",capital:"Seoul",
            lat:37.5665,lon:126.9780,region:.asia,gov:.republic,align:.western,
            gdp:1800,pop:52,mil:78,aggr:45,stab:82),
        CountryTemplate("PRK","North Korea",flag:"🇰🇵",capital:"Pyongyang",
            lat:39.0392,lon:125.7625,region:.asia,gov:.authoritarian,align:.eastern,
            gdp:30,pop:26,mil:68,aggr:90,stab:38,nuke:.declared),
        CountryTemplate("MNG","Mongolia",flag:"🇲🇳",capital:"Ulaanbaatar",
            lat:47.8864,lon:106.9057,region:.asia,gov:.republic,align:.nonAligned,
            gdp:20,pop:3,mil:22,aggr:20,stab:68),
        CountryTemplate("TWN","Taiwan",flag:"🇹🇼",capital:"Taipei",
            lat:25.0330,lon:121.5654,region:.asia,gov:.republic,align:.western,
            gdp:790,pop:24,mil:65,aggr:35,stab:85),
    ]

    // MARK: - Southeast Asia

    static let southeastAsia: [CountryTemplate] = [
        CountryTemplate("IDN","Indonesia",flag:"🇮🇩",capital:"Jakarta",
            lat:-6.2088,lon:106.8456,region:.asia,gov:.republic,align:.nonAligned,
            gdp:1400,pop:279,mil:58,aggr:35,stab:65),
        CountryTemplate("PHL","Philippines",flag:"🇵🇭",capital:"Manila",
            lat:14.5995,lon:120.9842,region:.asia,gov:.republic,align:.western,
            gdp:460,pop:117,mil:48,aggr:35,stab:58),
        CountryTemplate("VNM","Vietnam",flag:"🇻🇳",capital:"Hanoi",
            lat:21.0285,lon:105.8542,region:.asia,gov:.communist,align:.eastern,
            gdp:460,pop:100,mil:65,aggr:50,stab:72),
        CountryTemplate("THA","Thailand",flag:"🇹🇭",capital:"Bangkok",
            lat:13.7563,lon:100.5018,region:.asia,gov:.monarchy,align:.western,
            gdp:540,pop:71,mil:52,aggr:30,stab:65),
        CountryTemplate("MYS","Malaysia",flag:"🇲🇾",capital:"Kuala Lumpur",
            lat:3.1390,lon:101.6869,region:.asia,gov:.monarchy,align:.western,
            gdp:430,pop:34,mil:48,aggr:25,stab:72),
        CountryTemplate("SGP","Singapore",flag:"🇸🇬",capital:"Singapore",
            lat:1.3521,lon:103.8198,region:.asia,gov:.republic,align:.western,
            gdp:525,pop:6,mil:68,aggr:20,stab:92),
        CountryTemplate("MMR","Myanmar",flag:"🇲🇲",capital:"Naypyidaw",
            lat:19.7633,lon:96.0785,region:.asia,gov:.military,align:.eastern,
            gdp:65,pop:55,mil:52,aggr:55,stab:28),
        CountryTemplate("KHM","Cambodia",flag:"🇰🇭",capital:"Phnom Penh",
            lat:11.5564,lon:104.9282,region:.asia,gov:.monarchy,align:.eastern,
            gdp:32,pop:17,mil:32,aggr:35,stab:52),
        CountryTemplate("LAO","Laos",flag:"🇱🇦",capital:"Vientiane",
            lat:17.9757,lon:102.6331,region:.asia,gov:.communist,align:.eastern,
            gdp:22,pop:8,mil:28,aggr:30,stab:60),
        CountryTemplate("BRN","Brunei",flag:"🇧🇳",capital:"Bandar Seri Begawan",
            lat:4.9031,lon:114.9398,region:.asia,gov:.monarchy,align:.western,
            gdp:18,pop:0.5,mil:22,aggr:10,stab:80),
        CountryTemplate("TLS","Timor-Leste",flag:"🇹🇱",capital:"Dili",
            lat:-8.8742,lon:125.7275,region:.asia,gov:.republic,align:.nonAligned,
            gdp:4,pop:1.3,mil:10,aggr:15,stab:55),
    ]

    // MARK: - Africa (all 54 UN member states)

    static let africa: [CountryTemplate] = [
        // North Africa
        CountryTemplate("EGY","Egypt",flag:"🇪🇬",capital:"Cairo",
            lat:30.0444,lon:31.2357,region:.africa,gov:.authoritarian,align:.nonAligned,
            gdp:480,pop:110,mil:72,aggr:50,stab:58),
        CountryTemplate("DZA","Algeria",flag:"🇩🇿",capital:"Algiers",
            lat:36.7372,lon:3.0865,region:.africa,gov:.republic,align:.nonAligned,
            gdp:240,pop:46,mil:62,aggr:45,stab:58),
        CountryTemplate("MAR","Morocco",flag:"🇲🇦",capital:"Rabat",
            lat:34.0209,lon:-6.8417,region:.africa,gov:.monarchy,align:.western,
            gdp:150,pop:38,mil:52,aggr:35,stab:65),
        CountryTemplate("TUN","Tunisia",flag:"🇹🇳",capital:"Tunis",
            lat:36.8190,lon:10.1658,region:.africa,gov:.republic,align:.western,
            gdp:52,pop:12,mil:35,aggr:30,stab:52),
        CountryTemplate("LBY","Libya",flag:"🇱🇾",capital:"Tripoli",
            lat:32.9042,lon:13.1803,region:.africa,gov:.republic,align:.nonAligned,
            gdp:50,pop:7,mil:30,aggr:50,stab:22),
        CountryTemplate("SDN","Sudan",flag:"🇸🇩",capital:"Khartoum",
            lat:15.5007,lon:32.5599,region:.africa,gov:.authoritarian,align:.nonAligned,
            gdp:50,pop:48,mil:42,aggr:60,stab:25),
        CountryTemplate("SSD","South Sudan",flag:"🇸🇸",capital:"Juba",
            lat:4.8594,lon:31.5713,region:.africa,gov:.republic,align:.nonAligned,
            gdp:8,pop:12,mil:30,aggr:65,stab:15),

        // East Africa
        CountryTemplate("ETH","Ethiopia",flag:"🇪🇹",capital:"Addis Ababa",
            lat:9.0320,lon:38.7469,region:.africa,gov:.republic,align:.nonAligned,
            gdp:160,pop:125,mil:58,aggr:50,stab:42),
        CountryTemplate("KEN","Kenya",flag:"🇰🇪",capital:"Nairobi",
            lat:-1.2921,lon:36.8219,region:.africa,gov:.republic,align:.western,
            gdp:130,pop:56,mil:42,aggr:30,stab:58),
        CountryTemplate("TZA","Tanzania",flag:"🇹🇿",capital:"Dodoma",
            lat:-6.1630,lon:35.7516,region:.africa,gov:.republic,align:.nonAligned,
            gdp:80,pop:67,mil:32,aggr:25,stab:62),
        CountryTemplate("UGA","Uganda",flag:"🇺🇬",capital:"Kampala",
            lat:0.3476,lon:32.5825,region:.africa,gov:.republic,align:.nonAligned,
            gdp:50,pop:49,mil:35,aggr:40,stab:48),
        CountryTemplate("RWA","Rwanda",flag:"🇷🇼",capital:"Kigali",
            lat:-1.9403,lon:29.8739,region:.africa,gov:.republic,align:.nonAligned,
            gdp:15,pop:14,mil:25,aggr:45,stab:60),
        CountryTemplate("BDI","Burundi",flag:"🇧🇮",capital:"Gitega",
            lat:-3.3614,lon:29.3599,region:.africa,gov:.republic,align:.nonAligned,
            gdp:3,pop:12,mil:20,aggr:50,stab:28),
        CountryTemplate("SOM","Somalia",flag:"🇸🇴",capital:"Mogadishu",
            lat:2.0469,lon:45.3182,region:.africa,gov:.republic,align:.nonAligned,
            gdp:10,pop:18,mil:22,aggr:70,stab:12),
        CountryTemplate("ERI","Eritrea",flag:"🇪🇷",capital:"Asmara",
            lat:15.3229,lon:38.9317,region:.africa,gov:.authoritarian,align:.nonAligned,
            gdp:3,pop:3.5,mil:30,aggr:55,stab:25),
        CountryTemplate("DJI","Djibouti",flag:"🇩🇯",capital:"Djibouti",
            lat:11.8251,lon:42.5903,region:.africa,gov:.republic,align:.western,
            gdp:4,pop:1,mil:15,aggr:25,stab:55),
        CountryTemplate("MDG","Madagascar",flag:"🇲🇬",capital:"Antananarivo",
            lat:-18.9149,lon:47.5361,region:.africa,gov:.republic,align:.nonAligned,
            gdp:15,pop:28,mil:15,aggr:15,stab:45),

        // West Africa
        CountryTemplate("NGA","Nigeria",flag:"🇳🇬",capital:"Abuja",
            lat:9.0765,lon:7.3986,region:.africa,gov:.republic,align:.nonAligned,
            gdp:510,pop:225,mil:55,aggr:45,stab:42),
        CountryTemplate("GHA","Ghana",flag:"🇬🇭",capital:"Accra",
            lat:5.6037,lon:-0.1870,region:.africa,gov:.republic,align:.western,
            gdp:85,pop:34,mil:32,aggr:20,stab:68),
        CountryTemplate("CIV","Ivory Coast",flag:"🇨🇮",capital:"Yamoussoukro",
            lat:5.3600,lon:-4.0083,region:.africa,gov:.republic,align:.western,
            gdp:80,pop:29,mil:28,aggr:30,stab:55),
        CountryTemplate("SEN","Senegal",flag:"🇸🇳",capital:"Dakar",
            lat:14.6928,lon:-17.4467,region:.africa,gov:.republic,align:.western,
            gdp:30,pop:18,mil:25,aggr:20,stab:68),
        CountryTemplate("MLI","Mali",flag:"🇲🇱",capital:"Bamako",
            lat:12.6392,lon:-8.0029,region:.africa,gov:.military,align:.nonAligned,
            gdp:20,pop:23,mil:20,aggr:45,stab:25),
        CountryTemplate("BFA","Burkina Faso",flag:"🇧🇫",capital:"Ouagadougou",
            lat:12.3714,lon:-1.5197,region:.africa,gov:.military,align:.nonAligned,
            gdp:20,pop:22,mil:18,aggr:45,stab:22),
        CountryTemplate("NER","Niger",flag:"🇳🇪",capital:"Niamey",
            lat:13.5137,lon:2.1098,region:.africa,gov:.military,align:.nonAligned,
            gdp:15,pop:26,mil:15,aggr:40,stab:22),
        CountryTemplate("GIN","Guinea",flag:"🇬🇳",capital:"Conakry",
            lat:9.6412,lon:-13.5784,region:.africa,gov:.military,align:.nonAligned,
            gdp:20,pop:14,mil:18,aggr:40,stab:28),
        CountryTemplate("GNB","Guinea-Bissau",flag:"🇬🇼",capital:"Bissau",
            lat:11.8816,lon:-15.6177,region:.africa,gov:.republic,align:.nonAligned,
            gdp:2,pop:2,mil:8,aggr:35,stab:25),
        CountryTemplate("SLE","Sierra Leone",flag:"🇸🇱",capital:"Freetown",
            lat:8.4657,lon:-13.2317,region:.africa,gov:.republic,align:.western,
            gdp:8,pop:8,mil:12,aggr:30,stab:42),
        CountryTemplate("LBR","Liberia",flag:"🇱🇷",capital:"Monrovia",
            lat:6.3156,lon:-10.8074,region:.africa,gov:.republic,align:.western,
            gdp:4,pop:5,mil:10,aggr:35,stab:38),
        CountryTemplate("GMB","Gambia",flag:"🇬🇲",capital:"Banjul",
            lat:13.4531,lon:-16.5775,region:.africa,gov:.republic,align:.western,
            gdp:2,pop:2.7,mil:8,aggr:20,stab:55),
        CountryTemplate("CPV","Cape Verde",flag:"🇨🇻",capital:"Praia",
            lat:14.9331,lon:-23.5133,region:.africa,gov:.republic,align:.western,
            gdp:2,pop:0.6,mil:5,aggr:5,stab:82),
        CountryTemplate("MRT","Mauritania",flag:"🇲🇷",capital:"Nouakchott",
            lat:18.0735,lon:-15.9582,region:.africa,gov:.republic,align:.nonAligned,
            gdp:10,pop:4.6,mil:15,aggr:35,stab:42),
        CountryTemplate("TGO","Togo",flag:"🇹🇬",capital:"Lomé",
            lat:6.1375,lon:1.2123,region:.africa,gov:.republic,align:.nonAligned,
            gdp:10,pop:9,mil:15,aggr:30,stab:48),
        CountryTemplate("BEN","Benin",flag:"🇧🇯",capital:"Porto-Novo",
            lat:6.3654,lon:2.4183,region:.africa,gov:.republic,align:.western,
            gdp:20,pop:14,mil:15,aggr:20,stab:58),

        // Central Africa
        CountryTemplate("COD","DR Congo",flag:"🇨🇩",capital:"Kinshasa",
            lat:-4.3276,lon:15.3136,region:.africa,gov:.republic,align:.nonAligned,
            gdp:70,pop:102,mil:38,aggr:50,stab:25),
        CountryTemplate("COG","Republic of Congo",flag:"🇨🇬",capital:"Brazzaville",
            lat:-4.2661,lon:15.2832,region:.africa,gov:.republic,align:.nonAligned,
            gdp:15,pop:5.8,mil:18,aggr:35,stab:45),
        CountryTemplate("CMR","Cameroon",flag:"🇨🇲",capital:"Yaoundé",
            lat:3.8480,lon:11.5021,region:.africa,gov:.authoritarian,align:.nonAligned,
            gdp:50,pop:29,mil:32,aggr:35,stab:48),
        CountryTemplate("CAF","Central African Republic",flag:"🇨🇫",capital:"Bangui",
            lat:4.3947,lon:18.5582,region:.africa,gov:.republic,align:.nonAligned,
            gdp:3,pop:5.5,mil:10,aggr:55,stab:12),
        CountryTemplate("TCD","Chad",flag:"🇹🇩",capital:"N'Djamena",
            lat:12.1048,lon:15.0440,region:.africa,gov:.military,align:.nonAligned,
            gdp:12,pop:18,mil:20,aggr:55,stab:22),
        CountryTemplate("GNQ","Equatorial Guinea",flag:"🇬🇶",capital:"Malabo",
            lat:3.7500,lon:8.7833,region:.africa,gov:.authoritarian,align:.nonAligned,
            gdp:15,pop:1.5,mil:10,aggr:25,stab:42),
        CountryTemplate("GAB","Gabon",flag:"🇬🇦",capital:"Libreville",
            lat:0.4162,lon:9.4673,region:.africa,gov:.military,align:.nonAligned,
            gdp:22,pop:2.4,mil:15,aggr:25,stab:45),
        CountryTemplate("STP","São Tomé and Príncipe",flag:"🇸🇹",capital:"São Tomé",
            lat:0.1864,lon:6.6131,region:.africa,gov:.republic,align:.western,
            gdp:0.5,pop:0.2,mil:3,aggr:5,stab:72),

        // Southern Africa
        CountryTemplate("ZAF","South Africa",flag:"🇿🇦",capital:"Pretoria",
            lat:-25.7479,lon:28.2293,region:.africa,gov:.republic,align:.western,
            gdp:420,pop:61,mil:58,aggr:25,stab:55),
        CountryTemplate("AGO","Angola",flag:"🇦🇴",capital:"Luanda",
            lat:-8.8368,lon:13.2343,region:.africa,gov:.republic,align:.nonAligned,
            gdp:70,pop:36,mil:48,aggr:45,stab:42),
        CountryTemplate("MOZ","Mozambique",flag:"🇲🇿",capital:"Maputo",
            lat:-25.9653,lon:32.5892,region:.africa,gov:.republic,align:.nonAligned,
            gdp:18,pop:33,mil:18,aggr:30,stab:38),
        CountryTemplate("ZMB","Zambia",flag:"🇿🇲",capital:"Lusaka",
            lat:-15.3875,lon:28.3228,region:.africa,gov:.republic,align:.nonAligned,
            gdp:28,pop:20,mil:20,aggr:22,stab:52),
        CountryTemplate("ZWE","Zimbabwe",flag:"🇿🇼",capital:"Harare",
            lat:-17.8216,lon:31.0492,region:.africa,gov:.authoritarian,align:.nonAligned,
            gdp:35,pop:16,mil:30,aggr:45,stab:35),
        CountryTemplate("BWA","Botswana",flag:"🇧🇼",capital:"Gaborone",
            lat:-24.6540,lon:25.9061,region:.africa,gov:.republic,align:.western,
            gdp:20,pop:2.6,mil:15,aggr:10,stab:78),
        CountryTemplate("NAM","Namibia",flag:"🇳🇦",capital:"Windhoek",
            lat:-22.5597,lon:17.0832,region:.africa,gov:.republic,align:.nonAligned,
            gdp:12,pop:2.7,mil:15,aggr:12,stab:68),
        CountryTemplate("MWI","Malawi",flag:"🇲🇼",capital:"Lilongwe",
            lat:-13.9626,lon:33.7741,region:.africa,gov:.republic,align:.western,
            gdp:8,pop:21,mil:12,aggr:15,stab:52),
        CountryTemplate("SWZ","Eswatini",flag:"🇸🇿",capital:"Mbabane",
            lat:-26.5225,lon:31.4659,region:.africa,gov:.monarchy,align:.nonAligned,
            gdp:5,pop:1.2,mil:8,aggr:10,stab:55),
        CountryTemplate("LSO","Lesotho",flag:"🇱🇸",capital:"Maseru",
            lat:-29.3142,lon:27.4833,region:.africa,gov:.monarchy,align:.nonAligned,
            gdp:3,pop:2.2,mil:8,aggr:10,stab:52),
        CountryTemplate("MUS","Mauritius",flag:"🇲🇺",capital:"Port Louis",
            lat:-20.1609,lon:57.4983,region:.africa,gov:.republic,align:.western,
            gdp:14,pop:1.3,mil:8,aggr:5,stab:82),
        CountryTemplate("COM","Comoros",flag:"🇰🇲",capital:"Moroni",
            lat:-11.7022,lon:43.2551,region:.africa,gov:.republic,align:.nonAligned,
            gdp:1,pop:0.9,mil:5,aggr:20,stab:38),
        CountryTemplate("SYC","Seychelles",flag:"🇸🇨",capital:"Victoria",
            lat:-4.6796,lon:55.4920,region:.africa,gov:.republic,align:.western,
            gdp:2,pop:0.1,mil:3,aggr:5,stab:78),
    ]

    // MARK: - Oceania

    static let oceania: [CountryTemplate] = [
        CountryTemplate("AUS","Australia",flag:"🇦🇺",capital:"Canberra",
            lat:-35.2809,lon:149.1300,region:.oceania,gov:.monarchy,align:.western,
            gdp:1800,pop:27,mil:72,aggr:30,stab:92),
        CountryTemplate("NZL","New Zealand",flag:"🇳🇿",capital:"Wellington",
            lat:-41.2865,lon:174.7762,region:.oceania,gov:.monarchy,align:.western,
            gdp:260,pop:5,mil:42,aggr:15,stab:96),
        CountryTemplate("PNG","Papua New Guinea",flag:"🇵🇬",capital:"Port Moresby",
            lat:-9.4438,lon:147.1803,region:.oceania,gov:.monarchy,align:.nonAligned,
            gdp:30,pop:10,mil:22,aggr:25,stab:42),
        CountryTemplate("FJI","Fiji",flag:"🇫🇯",capital:"Suva",
            lat:-18.1416,lon:178.4419,region:.oceania,gov:.republic,align:.western,
            gdp:6,pop:0.9,mil:15,aggr:15,stab:62),
        CountryTemplate("SLB","Solomon Islands",flag:"🇸🇧",capital:"Honiara",
            lat:-9.4456,lon:160.0244,region:.oceania,gov:.monarchy,align:.nonAligned,
            gdp:2,pop:0.7,mil:5,aggr:10,stab:48),
        CountryTemplate("VUT","Vanuatu",flag:"🇻🇺",capital:"Port Vila",
            lat:-17.7334,lon:168.3210,region:.oceania,gov:.republic,align:.nonAligned,
            gdp:1,pop:0.3,mil:3,aggr:10,stab:58),
        CountryTemplate("WSM","Samoa",flag:"🇼🇸",capital:"Apia",
            lat:-13.8333,lon:-172.1333,region:.oceania,gov:.monarchy,align:.western,
            gdp:1,pop:0.2,mil:2,aggr:5,stab:72),
        CountryTemplate("TON","Tonga",flag:"🇹🇴",capital:"Nukuʻalofa",
            lat:-21.1393,lon:-175.2049,region:.oceania,gov:.monarchy,align:.western,
            gdp:0.5,pop:0.1,mil:2,aggr:5,stab:72),
        CountryTemplate("KIR","Kiribati",flag:"🇰🇮",capital:"South Tarawa",
            lat:1.3291,lon:172.9790,region:.oceania,gov:.republic,align:.nonAligned,
            gdp:0.2,pop:0.1,mil:0,aggr:2,stab:65),
        CountryTemplate("FSM","Micronesia",flag:"🇫🇲",capital:"Palikir",
            lat:6.9248,lon:158.1610,region:.oceania,gov:.republic,align:.western,
            gdp:0.4,pop:0.1,mil:0,aggr:2,stab:68),
        CountryTemplate("MHL","Marshall Islands",flag:"🇲🇭",capital:"Majuro",
            lat:7.1095,lon:171.3726,region:.oceania,gov:.republic,align:.western,
            gdp:0.3,pop:0.04,mil:0,aggr:2,stab:68),
        CountryTemplate("PLW","Palau",flag:"🇵🇼",capital:"Ngerulmud",
            lat:7.5000,lon:134.6243,region:.oceania,gov:.republic,align:.western,
            gdp:0.3,pop:0.02,mil:0,aggr:2,stab:75),
        CountryTemplate("NRU","Nauru",flag:"🇳🇷",capital:"Yaren",
            lat:-0.5228,lon:166.9315,region:.oceania,gov:.republic,align:.western,
            gdp:0.1,pop:0.01,mil:0,aggr:2,stab:65),
        CountryTemplate("TUV","Tuvalu",flag:"🇹🇻",capital:"Funafuti",
            lat:-8.5211,lon:179.1983,region:.oceania,gov:.monarchy,align:.western,
            gdp:0.05,pop:0.01,mil:0,aggr:1,stab:70),
    ]

    // MARK: - Key Territories

    static let territories: [CountryTemplate] = [
        CountryTemplate("XKX","Kosovo",flag:"🇽🇰",capital:"Pristina",
            lat:42.6026,lon:20.9030,region:.europe,gov:.republic,align:.western,
            gdp:10,pop:1.8,mil:12,aggr:30,stab:58),
        CountryTemplate("HKG","Hong Kong",flag:"🇭🇰",capital:"Hong Kong",
            lat:22.3193,lon:114.1694,region:.asia,gov:.republic,align:.western,
            gdp:400,pop:7,mil:5,aggr:10,stab:55),
    ]

    // MARK: - Historical Countries

    // MARK: - Pre-Soviet Russia (1789–1916)

    /// Tsarist Russian Empire — monarchy, no nuclear weapons, Eurasian great power
    static func russianEmpire(year: Int) -> CountryTemplate {
        let gdp: Double
        let pop: Double
        let mil: Int
        let aggr: Int
        switch year {
        case ..<1800: gdp = 0.05; pop = 35; mil = 55; aggr = 45
        case 1800..<1855: gdp = 0.08; pop = 60; mil = 65; aggr = 50   // Napoleonic + expansion
        case 1855..<1870: gdp = 0.09; pop = 70; mil = 55; aggr = 40   // Crimean War aftermath
        case 1870..<1900: gdp = 0.14; pop = 90; mil = 65; aggr = 55   // Industrialization begins
        default:           gdp = 0.25; pop = 130; mil = 72; aggr = 60  // Pre-WW1 peak
        }
        return CountryTemplate("RUS","Russian Empire",flag:"🇷🇺",capital:"Saint Petersburg",
            lat:59.9343,lon:30.3351,region:.europe,gov:.authoritarian,align:.nonAligned,
            gdp:gdp,pop:pop,mil:mil,aggr:aggr,stab:60,nuke:.none,yearEnd:1917)
    }

    /// Russia 1917–1921 — Revolution and Civil War, unstable transitional state
    static func revolutionaryRussia() -> CountryTemplate {
        CountryTemplate("RUS","Russia",flag:"🇷🇺",capital:"Petrograd",
            lat:59.9343,lon:30.3351,region:.europe,gov:.authoritarian,align:.nonAligned,
            gdp:0.04,pop:140,mil:35,aggr:50,stab:15,nuke:.none,yearEnd:1922)
    }

    // MARK: - Soviet Union (1922–1991)

    static func ussr(year: Int) -> CountryTemplate {
        return CountryTemplate("RUS","Soviet Union",flag:"🇷🇺",capital:"Moscow",
            lat:55.7558,lon:37.6173,region:.europe,gov:.communist,align:.eastern,
            gdp:year < 1960 ? 600 : year < 1975 ? 1500 : 2200,
            pop:year < 1960 ? 200 : year < 1980 ? 240 : 280,
            mil:90,aggr:80,stab:60,
            nuke:year < 1949 ? .none : .declared,
            yearEnd:1991)
    }

    // MARK: - German Historical Eras

    /// Pre-unification: loose confederation of 39 German states, Prussia dominant (1815-1871)
    static func germanConfederation(year: Int) -> CountryTemplate {
        let gdp: Double = year < 1850 ? 80 : 140
        let pop: Double = year < 1850 ? 35 : 42
        return CountryTemplate("DEU","German Confederation",flag:"🇩🇪",capital:"Frankfurt",
            lat:50.1109,lon:8.6821,region:.europe,gov:.authoritarian,align:.nonAligned,
            gdp:gdp,pop:pop,mil:55,aggr:30,stab:58,nuke:.none,yearEnd:1871)
    }

    /// Wilhelmine German Empire — unified, industrializing great power (1871-1918)
    static func germanEmpire(year: Int) -> CountryTemplate {
        let gdp: Double = year < 1900 ? 250 : 500
        return CountryTemplate("DEU","German Empire",flag:"🇩🇪",capital:"Berlin",
            lat:52.5200,lon:13.4050,region:.europe,gov:.authoritarian,align:.western,
            gdp:gdp,pop:year < 1900 ? 49 : 65,mil:80,aggr:55,stab:70,nuke:.none,yearEnd:1918)
    }

    /// Weimar Republic — democratic but unstable (1918-1933)
    static func weimarGermany(year: Int) -> CountryTemplate {
        CountryTemplate("DEU","Germany (Weimar Republic)",flag:"🇩🇪",capital:"Berlin",
            lat:52.5200,lon:13.4050,region:.europe,gov:.republic,align:.western,
            gdp:200,pop:60,mil:30,aggr:20,stab:40,nuke:.none,yearEnd:1933)
    }

    /// Third Reich — Nazi Germany (1933-1945)
    static func naziGermany(year: Int) -> CountryTemplate {
        let mil = year < 1940 ? 75 : 95
        let gdp: Double = year < 1940 ? 500 : 700
        return CountryTemplate("DEU","Nazi Germany",flag:"🇩🇪",capital:"Berlin",
            lat:52.5200,lon:13.4050,region:.europe,gov:.authoritarian,align:.nonAligned,
            gdp:gdp,pop:70,mil:mil,aggr:95,stab:65,nuke:.none,yearEnd:1945)
    }

    static func westGermany(year: Int) -> CountryTemplate {
        CountryTemplate("DEU","West Germany",flag:"🇩🇪",capital:"Bonn",
            lat:50.7374,lon:7.0982,region:.europe,gov:.republic,align:.western,
            gdp:year < 1960 ? 400 : year < 1975 ? 800 : 1200,
            pop:year < 1970 ? 57 : 61,
            mil:65,aggr:20,stab:88,yearEnd:1990)
    }

    static func eastGermany(year: Int) -> CountryTemplate {
        CountryTemplate("DDR","East Germany",flag:"🇩🇪",capital:"East Berlin",
            lat:52.5200,lon:13.4050,region:.europe,gov:.communist,align:.eastern,
            gdp:year < 1960 ? 100 : 180,
            pop:17,mil:50,aggr:40,stab:55,yearEnd:1990)
    }

    static func yugoslavia() -> CountryTemplate {
        CountryTemplate("YUG","Yugoslavia",flag:"🇷🇸",capital:"Belgrade",
            lat:44.8176,lon:20.4569,region:.europe,gov:.communist,align:.nonAligned,
            gdp:120,pop:24,mil:58,aggr:45,stab:55,yearEnd:1992)
    }

    static func czechoslovakia() -> CountryTemplate {
        CountryTemplate("CSK","Czechoslovakia",flag:"🇨🇿",capital:"Prague",
            lat:50.0755,lon:14.4378,region:.europe,gov:.republic,align:.eastern,
            gdp:200,pop:16,mil:45,aggr:25,stab:65,yearEnd:1993)
    }

    static func northVietnam() -> CountryTemplate {
        CountryTemplate("VNM","North Vietnam",flag:"🇻🇳",capital:"Hanoi",
            lat:21.0285,lon:105.8542,region:.asia,gov:.communist,align:.eastern,
            gdp:5,pop:22,mil:55,aggr:70,stab:55,yearEnd:1975)
    }

    static func southVietnam() -> CountryTemplate {
        CountryTemplate("SVN_VN","South Vietnam",flag:"🇻🇳",capital:"Saigon",
            lat:10.8231,lon:106.6297,region:.asia,gov:.military,align:.western,
            gdp:8,pop:20,mil:40,aggr:40,stab:35,yearEnd:1975)
    }
}

// MARK: - Extended GameState Era Integration

extension GameState {
    /// Build the country list appropriate for the current eraStartYear using WorldCountriesDatabase.
    func buildEraCountries() -> [Country] {
        let templates = WorldCountriesDatabase.countriesForYear(eraStartYear)
        return templates.map { $0.toCountry() }
    }
}
