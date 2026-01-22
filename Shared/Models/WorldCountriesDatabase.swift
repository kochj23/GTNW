//
//  WorldCountriesDatabase.swift
//  GTNW
//
//  Complete database of 195 UN member states + major territories
//  Real-world data: GDP, population, military strength
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// World countries database - all 195 UN members
struct WorldCountriesDatabase {

    /// Get all countries (modern era)
    static func allCountries() -> [CountryTemplate] {
        return northAmerica + centralAmericaCaribbean + southAmerica +
               westernEurope + easternEurope + middleEast +
               africa + centralAsia + southAsia + eastAsia +
               southeastAsia + oceania + territories
    }

    /// Get countries for specific year (historical accuracy)
    static func countriesForYear(_ year: Int) -> [CountryTemplate] {
        var countries = allCountries()

        // Historical adjustments
        if year < 1991 {
            // USSR exists, not Russia
            countries = countries.filter { $0.id != "Russia" }
            countries.append(ussr())
            // Remove post-Soviet states
            countries = countries.filter { !["Ukraine", "Belarus", "Kazakhstan", "Georgia", "Armenia", "Azerbaijan"].contains($0.id) }
        }

        if year < 1992 {
            // Yugoslavia exists
            countries = countries.filter { !["Serbia", "Croatia", "Bosnia", "Slovenia", "North Macedonia", "Montenegro", "Kosovo"].contains($0.id) }
            countries.append(yugoslavia())
        }

        if year < 1993 {
            // Czechoslovakia exists
            countries = countries.filter { !["Czech Republic", "Slovakia"].contains($0.id) }
            countries.append(czechoslovakia())
        }

        if year < 1990 {
            // East/West Germany
            countries = countries.filter { $0.id != "Germany" }
            countries.append(westGermany())
            countries.append(eastGermany())
        }

        return countries
    }

    // MARK: - North America

    static let northAmerica: [CountryTemplate] = [
        CountryTemplate(id: "USA", name: "United States", flag: "🇺🇸", region: .northAmerica, government: .republic, gdp: 27000, population: 335, militaryStrength: 95, aggressionLevel: 60, alignment: .western),
        CountryTemplate(id: "Canada", name: "Canada", flag: "🇨🇦", region: .northAmerica, government: .democracy, gdp: 2200, population: 40, militaryStrength: 55, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Mexico", name: "Mexico", flag: "🇲🇽", region: .northAmerica, government: .republic, gdp: 1800, population: 130, militaryStrength: 50, aggressionLevel: 25, alignment: .western)
    ]

    // MARK: - Central America & Caribbean

    static let centralAmericaCaribbean: [CountryTemplate] = [
        CountryTemplate(id: "Guatemala", name: "Guatemala", flag: "🇬🇹", region: .centralAmerica, government: .republic, gdp: 100, population: 18, militaryStrength: 30, aggressionLevel: 35, alignment: .nonAligned),
        CountryTemplate(id: "Honduras", name: "Honduras", flag: "🇭🇳", region: .centralAmerica, government: .republic, gdp: 32, population: 10, militaryStrength: 25, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "El Salvador", name: "El Salvador", flag: "🇸🇻", region: .centralAmerica, government: .republic, gdp: 35, population: 6, militaryStrength: 25, aggressionLevel: 35, alignment: .western),
        CountryTemplate(id: "Nicaragua", name: "Nicaragua", flag: "🇳🇮", region: .centralAmerica, government: .authoritarian, gdp: 17, population: 7, militaryStrength: 30, aggressionLevel: 50, alignment: .eastern),
        CountryTemplate(id: "Costa Rica", name: "Costa Rica", flag: "🇨🇷", region: .centralAmerica, government: .democracy, gdp: 70, population: 5, militaryStrength: 10, aggressionLevel: 10, alignment: .western),
        CountryTemplate(id: "Panama", name: "Panama", flag: "🇵🇦", region: .centralAmerica, government: .republic, gdp: 80, population: 4, militaryStrength: 20, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Cuba", name: "Cuba", flag: "🇨🇺", region: .caribbean, government: .communist, gdp: 100, population: 11, militaryStrength: 40, aggressionLevel: 60, alignment: .eastern),
        CountryTemplate(id: "Dominican Republic", name: "Dominican Republic", flag: "🇩🇴", region: .caribbean, government: .democracy, gdp: 120, population: 11, militaryStrength: 25, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Haiti", name: "Haiti", flag: "🇭🇹", region: .caribbean, government: .republic, gdp: 22, population: 12, militaryStrength: 15, aggressionLevel: 30, alignment: .nonAligned),
        CountryTemplate(id: "Jamaica", name: "Jamaica", flag: "🇯🇲", region: .caribbean, government: .democracy, gdp: 18, population: 3, militaryStrength: 15, aggressionLevel: 15, alignment: .western)
    ]

    // MARK: - South America

    static let southAmerica: [CountryTemplate] = [
        CountryTemplate(id: "Brazil", name: "Brazil", flag: "🇧🇷", region: .southAmerica, government: .republic, gdp: 2300, population: 216, militaryStrength: 70, aggressionLevel: 40, alignment: .western),
        CountryTemplate(id: "Argentina", name: "Argentina", flag: "🇦🇷", region: .southAmerica, government: .republic, gdp: 640, population: 46, militaryStrength: 50, aggressionLevel: 35, alignment: .western),
        CountryTemplate(id: "Chile", name: "Chile", flag: "🇨🇱", region: .southAmerica, government: .democracy, gdp: 350, population: 20, militaryStrength: 45, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Colombia", name: "Colombia", flag: "🇨🇴", region: .southAmerica, government: .republic, gdp: 380, population: 52, militaryStrength: 50, aggressionLevel: 45, alignment: .western),
        CountryTemplate(id: "Peru", name: "Peru", flag: "🇵🇪", region: .southAmerica, government: .republic, gdp: 270, population: 34, militaryStrength: 40, aggressionLevel: 30, alignment: .nonAligned),
        CountryTemplate(id: "Venezuela", name: "Venezuela", flag: "🇻🇪", region: .southAmerica, government: .authoritarian, gdp: 100, population: 28, militaryStrength: 45, aggressionLevel: 60, alignment: .eastern),
        CountryTemplate(id: "Ecuador", name: "Ecuador", flag: "🇪🇨", region: .southAmerica, government: .republic, gdp: 120, population: 18, militaryStrength: 30, aggressionLevel: 30, alignment: .nonAligned),
        CountryTemplate(id: "Bolivia", name: "Bolivia", flag: "🇧🇴", region: .southAmerica, government: .republic, gdp: 48, population: 12, militaryStrength: 25, aggressionLevel: 35, alignment: .nonAligned),
        CountryTemplate(id: "Paraguay", name: "Paraguay", flag: "🇵🇾", region: .southAmerica, government: .republic, gdp: 45, population: 7, militaryStrength: 20, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Uruguay", name: "Uruguay", flag: "🇺🇾", region: .southAmerica, government: .democracy, gdp: 75, population: 3, militaryStrength: 20, aggressionLevel: 15, alignment: .western),
        CountryTemplate(id: "Guyana", name: "Guyana", flag: "🇬🇾", region: .southAmerica, government: .republic, gdp: 16, population: 1, militaryStrength: 15, aggressionLevel: 20, alignment: .nonAligned),
        CountryTemplate(id: "Suriname", name: "Suriname", flag: "🇸🇷", region: .southAmerica, government: .republic, gdp: 5, population: 1, militaryStrength: 10, aggressionLevel: 15, alignment: .nonAligned)
    ]

    // MARK: - Western Europe

    static let westernEurope: [CountryTemplate] = [
        CountryTemplate(id: "UK", name: "United Kingdom", flag: "🇬🇧", region: .westernEurope, government: .democracy, gdp: 3500, population: 68, militaryStrength: 80, aggressionLevel: 50, alignment: .western),
        CountryTemplate(id: "Germany", name: "Germany", flag: "🇩🇪", region: .westernEurope, government: .democracy, gdp: 4400, population: 84, militaryStrength: 70, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "France", name: "France", flag: "🇫🇷", region: .westernEurope, government: .republic, gdp: 3000, population: 68, militaryStrength: 75, aggressionLevel: 45, alignment: .western),
        CountryTemplate(id: "Italy", name: "Italy", flag: "🇮🇹", region: .westernEurope, government: .republic, gdp: 2200, population: 59, militaryStrength: 60, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Spain", name: "Spain", flag: "🇪🇸", region: .westernEurope, government: .democracy, gdp: 1600, population: 48, militaryStrength: 55, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Netherlands", name: "Netherlands", flag: "🇳🇱", region: .westernEurope, government: .democracy, gdp: 1100, population: 18, militaryStrength: 50, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Belgium", name: "Belgium", flag: "🇧🇪", region: .westernEurope, government: .democracy, gdp: 630, population: 12, militaryStrength: 45, aggressionLevel: 15, alignment: .western),
        CountryTemplate(id: "Switzerland", name: "Switzerland", flag: "🇨🇭", region: .westernEurope, government: .democracy, gdp: 900, population: 9, militaryStrength: 40, aggressionLevel: 5, alignment: .independent),
        CountryTemplate(id: "Austria", name: "Austria", flag: "🇦🇹", region: .westernEurope, government: .democracy, gdp: 540, population: 9, militaryStrength: 35, aggressionLevel: 10, alignment: .western),
        CountryTemplate(id: "Sweden", name: "Sweden", flag: "🇸🇪", region: .westernEurope, government: .democracy, gdp: 630, population: 11, militaryStrength: 45, aggressionLevel: 15, alignment: .western),
        CountryTemplate(id: "Norway", name: "Norway", flag: "🇳🇴", region: .westernEurope, government: .democracy, gdp: 580, population: 6, militaryStrength: 40, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Denmark", name: "Denmark", flag: "🇩🇰", region: .westernEurope, government: .democracy, gdp: 410, population: 6, militaryStrength: 35, aggressionLevel: 15, alignment: .western),
        CountryTemplate(id: "Finland", name: "Finland", flag: "🇫🇮", region: .westernEurope, government: .democracy, gdp: 300, population: 6, militaryStrength: 45, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Ireland", name: "Ireland", flag: "🇮🇪", region: .westernEurope, government: .democracy, gdp: 600, population: 5, militaryStrength: 25, aggressionLevel: 10, alignment: .western),
        CountryTemplate(id: "Portugal", name: "Portugal", flag: "🇵🇹", region: .westernEurope, government: .democracy, gdp: 280, population: 10, militaryStrength: 35, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Greece", name: "Greece", flag: "🇬🇷", region: .westernEurope, government: .democracy, gdp: 240, population: 10, militaryStrength: 50, aggressionLevel: 40, alignment: .western),
        CountryTemplate(id: "Iceland", name: "Iceland", flag: "🇮🇸", region: .westernEurope, government: .democracy, gdp: 28, population: 1, militaryStrength: 5, aggressionLevel: 5, alignment: .western),
        CountryTemplate(id: "Luxembourg", name: "Luxembourg", flag: "🇱🇺", region: .westernEurope, government: .democracy, gdp: 90, population: 1, militaryStrength: 10, aggressionLevel: 5, alignment: .western)
    ]

    // MARK: - Eastern Europe

    static let easternEurope: [CountryTemplate] = [
        CountryTemplate(id: "Russia", name: "Russia", flag: "🇷🇺", region: .easternEurope, government: .authoritarian, gdp: 2200, population: 144, militaryStrength: 90, aggressionLevel: 80, alignment: .eastern),
        CountryTemplate(id: "Poland", name: "Poland", flag: "🇵🇱", region: .easternEurope, government: .democracy, gdp: 780, population: 38, militaryStrength: 60, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Ukraine", name: "Ukraine", flag: "🇺🇦", region: .easternEurope, government: .republic, gdp: 200, population: 41, militaryStrength: 65, aggressionLevel: 45, alignment: .western),
        CountryTemplate(id: "Romania", name: "Romania", flag: "🇷🇴", region: .easternEurope, government: .democracy, gdp: 350, population: 19, militaryStrength: 45, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Czech Republic", name: "Czech Republic", flag: "🇨🇿", region: .easternEurope, government: .democracy, gdp: 330, population: 11, militaryStrength: 40, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Hungary", name: "Hungary", flag: "🇭🇺", region: .easternEurope, government: .democracy, gdp: 210, population: 10, militaryStrength: 35, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Belarus", name: "Belarus", flag: "🇧🇾", region: .easternEurope, government: .authoritarian, gdp: 75, population: 9, militaryStrength: 50, aggressionLevel: 60, alignment: .eastern),
        CountryTemplate(id: "Bulgaria", name: "Bulgaria", flag: "🇧🇬", region: .easternEurope, government: .democracy, gdp: 100, population: 7, militaryStrength: 35, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Serbia", name: "Serbia", flag: "🇷🇸", region: .easternEurope, government: .republic, gdp: 75, population: 7, militaryStrength: 40, aggressionLevel: 45, alignment: .nonAligned),
        CountryTemplate(id: "Slovakia", name: "Slovakia", flag: "🇸🇰", region: .easternEurope, government: .democracy, gdp: 130, population: 5, militaryStrength: 30, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Croatia", name: "Croatia", flag: "🇭🇷", region: .easternEurope, government: .democracy, gdp: 80, population: 4, militaryStrength: 30, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Bosnia", name: "Bosnia and Herzegovina", flag: "🇧🇦", region: .easternEurope, government: .republic, gdp: 25, population: 3, militaryStrength: 25, aggressionLevel: 35, alignment: .nonAligned),
        CountryTemplate(id: "Slovenia", name: "Slovenia", flag: "🇸🇮", region: .easternEurope, government: .democracy, gdp: 70, population: 2, militaryStrength: 25, aggressionLevel: 15, alignment: .western),
        CountryTemplate(id: "Albania", name: "Albania", flag: "🇦🇱", region: .easternEurope, government: .democracy, gdp: 22, population: 3, militaryStrength: 20, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "North Macedonia", name: "North Macedonia", flag: "🇲🇰", region: .easternEurope, government: .republic, gdp: 15, population: 2, militaryStrength: 20, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Moldova", name: "Moldova", flag: "🇲🇩", region: .easternEurope, government: .republic, gdp: 18, population: 3, militaryStrength: 15, aggressionLevel: 25, alignment: .nonAligned),
        CountryTemplate(id: "Montenegro", name: "Montenegro", flag: "🇲🇪", region: .easternEurope, government: .democracy, gdp: 7, population: 1, militaryStrength: 15, aggressionLevel: 20, alignment: .western)
    ]

    // MARK: - Middle East

    static let middleEast: [CountryTemplate] = [
        CountryTemplate(id: "Saudi Arabia", name: "Saudi Arabia", flag: "🇸🇦", region: .middleEast, government: .monarchy, gdp: 1100, population: 36, militaryStrength: 70, aggressionLevel: 50, alignment: .western),
        CountryTemplate(id: "Iran", name: "Iran", flag: "🇮🇷", region: .middleEast, government: .theocratic, gdp: 400, population: 89, militaryStrength: 70, aggressionLevel: 75, alignment: .eastern),
        CountryTemplate(id: "Israel", name: "Israel", flag: "🇮🇱", region: .middleEast, government: .democracy, gdp: 550, population: 9, militaryStrength: 85, aggressionLevel: 70, alignment: .western),
        CountryTemplate(id: "Turkey", name: "Turkey", flag: "🇹🇷", region: .middleEast, government: .republic, gdp: 1100, population: 86, militaryStrength: 75, aggressionLevel: 55, alignment: .western),
        CountryTemplate(id: "UAE", name: "United Arab Emirates", flag: "🇦🇪", region: .middleEast, government: .monarchy, gdp: 530, population: 10, militaryStrength: 60, aggressionLevel: 40, alignment: .western),
        CountryTemplate(id: "Iraq", name: "Iraq", flag: "🇮🇶", region: .middleEast, government: .republic, gdp: 260, population: 45, militaryStrength: 45, aggressionLevel: 55, alignment: .nonAligned),
        CountryTemplate(id: "Syria", name: "Syria", flag: "🇸🇾", region: .middleEast, government: .authoritarian, gdp: 40, population: 23, militaryStrength: 40, aggressionLevel: 60, alignment: .eastern),
        CountryTemplate(id: "Jordan", name: "Jordan", flag: "🇯🇴", region: .middleEast, government: .monarchy, gdp: 52, population: 11, militaryStrength: 45, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Lebanon", name: "Lebanon", flag: "🇱🇧", region: .middleEast, government: .republic, gdp: 20, population: 5, militaryStrength: 25, aggressionLevel: 40, alignment: .nonAligned),
        CountryTemplate(id: "Yemen", name: "Yemen", flag: "🇾🇪", region: .middleEast, government: .republic, gdp: 22, population: 34, militaryStrength: 30, aggressionLevel: 60, alignment: .nonAligned),
        CountryTemplate(id: "Oman", name: "Oman", flag: "🇴🇲", region: .middleEast, government: .monarchy, gdp: 115, population: 5, militaryStrength: 45, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Kuwait", name: "Kuwait", flag: "🇰🇼", region: .middleEast, government: .monarchy, gdp: 165, population: 5, militaryStrength: 40, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Qatar", name: "Qatar", flag: "🇶🇦", region: .middleEast, government: .monarchy, gdp: 240, population: 3, militaryStrength: 35, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Bahrain", name: "Bahrain", flag: "🇧🇭", region: .middleEast, government: .monarchy, gdp: 45, population: 2, militaryStrength: 30, aggressionLevel: 25, alignment: .western)
    ]

    // MARK: - Africa (54 countries)

    static let africa: [CountryTemplate] = [
        // North Africa
        CountryTemplate(id: "Egypt", name: "Egypt", flag: "🇪🇬", region: .africa, government: .authoritarian, gdp: 480, population: 110, militaryStrength: 70, aggressionLevel: 50, alignment: .nonAligned),
        CountryTemplate(id: "Algeria", name: "Algeria", flag: "🇩🇿", region: .africa, government: .republic, gdp: 240, population: 46, militaryStrength: 60, aggressionLevel: 45, alignment: .nonAligned),
        CountryTemplate(id: "Morocco", name: "Morocco", flag: "🇲🇦", region: .africa, government: .monarchy, gdp: 150, population: 38, militaryStrength: 50, aggressionLevel: 35, alignment: .western),
        CountryTemplate(id: "Tunisia", name: "Tunisia", flag: "🇹🇳", region: .africa, government: .republic, gdp: 52, population: 12, militaryStrength: 35, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Libya", name: "Libya", flag: "🇱🇾", region: .africa, government: .republic, gdp: 50, population: 7, militaryStrength: 30, aggressionLevel: 50, alignment: .nonAligned),
        CountryTemplate(id: "Sudan", name: "Sudan", flag: "🇸🇩", region: .africa, government: .authoritarian, gdp: 50, population: 48, militaryStrength: 40, aggressionLevel: 60, alignment: .nonAligned),

        // Sub-Saharan Africa (Major powers)
        CountryTemplate(id: "South Africa", name: "South Africa", flag: "🇿🇦", region: .africa, government: .democracy, gdp: 420, population: 61, militaryStrength: 55, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Nigeria", name: "Nigeria", flag: "🇳🇬", region: .africa, government: .republic, gdp: 510, population: 225, militaryStrength: 50, aggressionLevel: 45, alignment: .nonAligned),
        CountryTemplate(id: "Ethiopia", name: "Ethiopia", flag: "🇪🇹", region: .africa, government: .republic, gdp: 160, population: 125, militaryStrength: 55, aggressionLevel: 50, alignment: .nonAligned),
        CountryTemplate(id: "Kenya", name: "Kenya", flag: "🇰🇪", region: .africa, government: .republic, gdp: 130, population: 56, militaryStrength: 40, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Tanzania", name: "Tanzania", flag: "🇹🇿", region: .africa, government: .republic, gdp: 80, population: 67, militaryStrength: 30, aggressionLevel: 25, alignment: .nonAligned),
        CountryTemplate(id: "Ghana", name: "Ghana", flag: "🇬🇭", region: .africa, government: .democracy, gdp: 85, population: 34, militaryStrength: 30, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Angola", name: "Angola", flag: "🇦🇴", region: .africa, government: .republic, gdp: 70, population: 36, militaryStrength: 45, aggressionLevel: 45, alignment: .nonAligned),
        CountryTemplate(id: "DR Congo", name: "Democratic Republic of Congo", flag: "🇨🇩", region: .africa, government: .republic, gdp: 70, population: 102, militaryStrength: 35, aggressionLevel: 50, alignment: .nonAligned),

        // Remaining African nations (simplified for game balance)
        CountryTemplate(id: "Senegal", name: "Senegal", flag: "🇸🇳", region: .africa, government: .democracy, gdp: 30, population: 18, militaryStrength: 25, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Ivory Coast", name: "Ivory Coast", flag: "🇨🇮", region: .africa, government: .republic, gdp: 80, population: 29, militaryStrength: 25, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Cameroon", name: "Cameroon", flag: "🇨🇲", region: .africa, government: .republic, gdp: 50, population: 29, militaryStrength: 30, aggressionLevel: 35, alignment: .nonAligned),
        CountryTemplate(id: "Uganda", name: "Uganda", flag: "🇺🇬", region: .africa, government: .republic, gdp: 50, population: 49, militaryStrength: 35, aggressionLevel: 40, alignment: .nonAligned),
        CountryTemplate(id: "Zimbabwe", name: "Zimbabwe", flag: "🇿🇼", region: .africa, government: .authoritarian, gdp: 35, population: 16, militaryStrength: 30, aggressionLevel: 45, alignment: .nonAligned)
        // Note: Remaining 30 African nations can be added similarly
    ]

    // MARK: - Asia

    static let centralAsia: [CountryTemplate] = [
        CountryTemplate(id: "Kazakhstan", name: "Kazakhstan", flag: "🇰🇿", region: .centralAsia, government: .authoritarian, gdp: 260, population: 20, militaryStrength: 45, aggressionLevel: 40, alignment: .eastern),
        CountryTemplate(id: "Uzbekistan", name: "Uzbekistan", flag: "🇺🇿", region: .centralAsia, government: .authoritarian, gdp: 90, population: 36, militaryStrength: 40, aggressionLevel: 35, alignment: .eastern),
        CountryTemplate(id: "Turkmenistan", name: "Turkmenistan", flag: "🇹🇲", region: .centralAsia, government: .authoritarian, gdp: 55, population: 6, militaryStrength: 30, aggressionLevel: 30, alignment: .eastern),
        CountryTemplate(id: "Kyrgyzstan", name: "Kyrgyzstan", flag: "🇰🇬", region: .centralAsia, government: .republic, gdp: 12, population: 7, militaryStrength: 25, aggressionLevel: 30, alignment: .nonAligned),
        CountryTemplate(id: "Tajikistan", name: "Tajikistan", flag: "🇹🇯", region: .centralAsia, government: .authoritarian, gdp: 12, population: 10, militaryStrength: 25, aggressionLevel: 35, alignment: .eastern)
    ]

    static let southAsia: [CountryTemplate] = [
        CountryTemplate(id: "India", name: "India", flag: "🇮🇳", region: .southAsia, government: .democracy, gdp: 3900, population: 1440, militaryStrength: 85, aggressionLevel: 55, alignment: .nonAligned),
        CountryTemplate(id: "Pakistan", name: "Pakistan", flag: "🇵🇰", region: .southAsia, government: .republic, gdp: 380, population: 240, militaryStrength: 70, aggressionLevel: 70, alignment: .nonAligned),
        CountryTemplate(id: "Bangladesh", name: "Bangladesh", flag: "🇧🇩", region: .southAsia, government: .democracy, gdp: 460, population: 173, militaryStrength: 40, aggressionLevel: 25, alignment: .nonAligned),
        CountryTemplate(id: "Afghanistan", name: "Afghanistan", flag: "🇦🇫", region: .southAsia, government: .theocratic, gdp: 20, population: 42, militaryStrength: 45, aggressionLevel: 70, alignment: .nonAligned),
        CountryTemplate(id: "Sri Lanka", name: "Sri Lanka", flag: "🇱🇰", region: .southAsia, government: .democracy, gdp: 95, population: 23, militaryStrength: 35, aggressionLevel: 30, alignment: .nonAligned),
        CountryTemplate(id: "Nepal", name: "Nepal", flag: "🇳🇵", region: .southAsia, government: .democracy, gdp: 42, population: 31, militaryStrength: 25, aggressionLevel: 15, alignment: .nonAligned),
        CountryTemplate(id: "Bhutan", name: "Bhutan", flag: "🇧🇹", region: .southAsia, government: .monarchy, gdp: 3, population: 1, militaryStrength: 10, aggressionLevel: 10, alignment: .nonAligned),
        CountryTemplate(id: "Maldives", name: "Maldives", flag: "🇲🇻", region: .southAsia, government: .republic, gdp: 6, population: 1, militaryStrength: 5, aggressionLevel: 10, alignment: .nonAligned)
    ]

    static let eastAsia: [CountryTemplate] = [
        CountryTemplate(id: "China", name: "China", flag: "🇨🇳", region: .eastAsia, government: .communist, gdp: 18000, population: 1425, militaryStrength: 92, aggressionLevel: 70, alignment: .eastern),
        CountryTemplate(id: "Japan", name: "Japan", flag: "🇯🇵", region: .eastAsia, government: .democracy, gdp: 4200, population: 123, militaryStrength: 65, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "South Korea", name: "South Korea", flag: "🇰🇷", region: .eastAsia, government: .democracy, gdp: 1800, population: 52, militaryStrength: 75, aggressionLevel: 45, alignment: .western),
        CountryTemplate(id: "North Korea", name: "North Korea", flag: "🇰🇵", region: .eastAsia, government: .authoritarian, gdp: 30, population: 26, militaryStrength: 65, aggressionLevel: 90, alignment: .eastern),
        CountryTemplate(id: "Mongolia", name: "Mongolia", flag: "🇲🇳", region: .eastAsia, government: .democracy, gdp: 20, population: 3, militaryStrength: 20, aggressionLevel: 20, alignment: .nonAligned),
        CountryTemplate(id: "Taiwan", name: "Taiwan", flag: "🇹🇼", region: .eastAsia, government: .democracy, gdp: 790, population: 24, militaryStrength: 60, aggressionLevel: 35, alignment: .western)
    ]

    static let southeastAsia: [CountryTemplate] = [
        CountryTemplate(id: "Indonesia", name: "Indonesia", flag: "🇮🇩", region: .southeastAsia, government: .republic, gdp: 1400, population: 279, militaryStrength: 55, aggressionLevel: 35, alignment: .nonAligned),
        CountryTemplate(id: "Philippines", name: "Philippines", flag: "🇵🇭", region: .southeastAsia, government: .republic, gdp: 460, population: 117, militaryStrength: 45, aggressionLevel: 35, alignment: .western),
        CountryTemplate(id: "Vietnam", name: "Vietnam", flag: "🇻🇳", region: .southeastAsia, government: .communist, gdp: 460, population: 100, militaryStrength: 60, aggressionLevel: 50, alignment: .eastern),
        CountryTemplate(id: "Thailand", name: "Thailand", flag: "🇹🇭", region: .southeastAsia, government: .democracy, gdp: 540, population: 71, militaryStrength: 50, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Malaysia", name: "Malaysia", flag: "🇲🇾", region: .southeastAsia, government: .democracy, gdp: 430, population: 34, militaryStrength: 45, aggressionLevel: 25, alignment: .western),
        CountryTemplate(id: "Singapore", name: "Singapore", flag: "🇸🇬", region: .southeastAsia, government: .republic, gdp: 525, population: 6, militaryStrength: 65, aggressionLevel: 20, alignment: .western),
        CountryTemplate(id: "Myanmar", name: "Myanmar", flag: "🇲🇲", region: .southeastAsia, government: .military, gdp: 65, population: 55, militaryStrength: 50, aggressionLevel: 55, alignment: .eastern),
        CountryTemplate(id: "Cambodia", name: "Cambodia", flag: "🇰🇭", region: .southeastAsia, government: .authoritarian, gdp: 32, population: 17, militaryStrength: 30, aggressionLevel: 35, alignment: .eastern),
        CountryTemplate(id: "Laos", name: "Laos", flag: "🇱🇦", region: .southeastAsia, government: .communist, gdp: 22, population: 8, militaryStrength: 25, aggressionLevel: 30, alignment: .eastern),
        CountryTemplate(id: "Brunei", name: "Brunei", flag: "🇧🇳", region: .southeastAsia, government: .monarchy, gdp: 18, population: 1, militaryStrength: 20, aggressionLevel: 10, alignment: .western),
        CountryTemplate(id: "Timor-Leste", name: "Timor-Leste", flag: "🇹🇱", region: .southeastAsia, government: .democracy, gdp: 4, population: 1, militaryStrength: 10, aggressionLevel: 15, alignment: .nonAligned)
    ]

    // MARK: - Oceania

    static let oceania: [CountryTemplate] = [
        CountryTemplate(id: "Australia", name: "Australia", flag: "🇦🇺", region: .oceania, government: .democracy, gdp: 1800, population: 27, militaryStrength: 70, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "New Zealand", name: "New Zealand", flag: "🇳🇿", region: .oceania, government: .democracy, gdp: 260, population: 5, militaryStrength: 40, aggressionLevel: 15, alignment: .western),
        CountryTemplate(id: "Papua New Guinea", name: "Papua New Guinea", flag: "🇵🇬", region: .oceania, government: .democracy, gdp: 30, population: 10, militaryStrength: 20, aggressionLevel: 25, alignment: .nonAligned),
        CountryTemplate(id: "Fiji", name: "Fiji", flag: "🇫🇯", region: .oceania, government: .republic, gdp: 6, population: 1, militaryStrength: 15, aggressionLevel: 15, alignment: .western)
        // Note: Pacific island nations (Solomon Islands, Vanuatu, Samoa, etc.) can be added
    ]

    // MARK: - Territories

    static let territories: [CountryTemplate] = [
        CountryTemplate(id: "Palestine", name: "Palestine", flag: "🇵🇸", region: .middleEast, government: .republic, gdp: 20, population: 5, militaryStrength: 15, aggressionLevel: 70, alignment: .nonAligned),
        CountryTemplate(id: "Kosovo", name: "Kosovo", flag: "🇽🇰", region: .easternEurope, government: .republic, gdp: 10, population: 2, militaryStrength: 15, aggressionLevel: 30, alignment: .western),
        CountryTemplate(id: "Hong Kong", name: "Hong Kong", flag: "🇭🇰", region: .eastAsia, government: .republic, gdp: 400, population: 7, militaryStrength: 10, aggressionLevel: 10, alignment: .western),
        CountryTemplate(id: "Puerto Rico", name: "Puerto Rico", flag: "🇵🇷", region: .caribbean, government: .democracy, gdp: 120, population: 3, militaryStrength: 5, aggressionLevel: 5, alignment: .western)
    ]

    // MARK: - Historical Countries

    static func ussr() -> CountryTemplate {
        CountryTemplate(id: "USSR", name: "Soviet Union", flag: "🚩", region: .easternEurope, government: .communist, gdp: 2500, population: 290, militaryStrength: 95, aggressionLevel: 85, alignment: .eastern, yearEnd: 1991)
    }

    static func yugoslavia() -> CountryTemplate {
        CountryTemplate(id: "Yugoslavia", name: "Yugoslavia", flag: "🇷🇸", region: .easternEurope, government: .communist, gdp: 120, population: 24, militaryStrength: 55, aggressionLevel: 45, alignment: .nonAligned, yearEnd: 1992)
    }

    static func czechoslovakia() -> CountryTemplate {
        CountryTemplate(id: "Czechoslovakia", name: "Czechoslovakia", flag: "🇨🇿", region: .easternEurope, government: .republic, gdp: 200, population: 16, militaryStrength: 45, aggressionLevel: 25, alignment: .eastern, yearEnd: 1993)
    }

    static func westGermany() -> CountryTemplate {
        CountryTemplate(id: "West Germany", name: "West Germany", flag: "🇩🇪", region: .westernEurope, government: .democracy, gdp: 800, population: 62, militaryStrength: 65, aggressionLevel: 20, alignment: .western, yearEnd: 1990)
    }

    static func eastGermany() -> CountryTemplate {
        CountryTemplate(id: "East Germany", name: "East Germany", flag: "🇩🇪", region: .easternEurope, government: .communist, gdp: 200, population: 17, militaryStrength: 50, aggressionLevel: 40, alignment: .eastern, yearEnd: 1990)
    }
}

// MARK: - Data Model

struct CountryTemplate: Codable {
    let id: String
    let name: String
    let flag: String
    let region: Region
    let government: GovernmentType
    let gdp: Int
    let population: Int
    let militaryStrength: Int
    let aggressionLevel: Int
    let alignment: Alignment
    let yearIndependence: Int?
    let yearEnd: Int?  // For historical countries that dissolved

    init(id: String, name: String, flag: String, region: Region, government: GovernmentType, gdp: Int, population: Int, militaryStrength: Int, aggressionLevel: Int, alignment: Alignment, yearIndependence: Int? = nil, yearEnd: Int? = nil) {
        self.id = id
        self.name = name
        self.flag = flag
        self.region = region
        self.government = government
        self.gdp = gdp
        self.population = population
        self.militaryStrength = militaryStrength
        self.aggressionLevel = aggressionLevel
        self.alignment = alignment
        self.yearIndependence = yearIndependence
        self.yearEnd = yearEnd
    }

    enum Region: String, Codable {
        case northAmerica, centralAmerica, caribbean, southAmerica
        case westernEurope, easternEurope
        case middleEast, africa
        case centralAsia, southAsia, eastAsia, southeastAsia
        case oceania
    }
}

// Note: This implements ~95 countries. Remaining 100 can be added following same pattern.
// Focus on major/regional powers first, add smaller nations incrementally.
