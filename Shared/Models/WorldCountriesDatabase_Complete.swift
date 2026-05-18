//
//  WorldCountriesDatabase_Complete.swift
//  GTNW
//
//  Complete 195 UN Member States + Historical Nations
//  Adding 59 missing countries to reach full coverage
//  Created by Jordan Koch on 2026-01-26
//

import Foundation

extension WorldCountriesDatabase {

    /// ALL missing countries to reach 195 UN members
    static let additionalCountries: [CountryTemplate] = [
        // Small European nations
        CountryTemplate(id: "Andorra", name: "Andorra", alignment: .neutral, governmentType: .democracy,
                       gdp: 3.2, population: 0.08, militaryStrength: 0, economicStrength: 2, lat: 42.5, lon: 1.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Liechtenstein", name: "Liechtenstein", alignment: .neutral, governmentType: .monarchy,
                       gdp: 6.6, population: 0.04, militaryStrength: 0, economicStrength: 5, lat: 47.1, lon: 9.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Monaco", name: "Monaco", alignment: .western, governmentType: .monarchy,
                       gdp: 7.2, population: 0.04, militaryStrength: 0, economicStrength: 5, lat: 43.7, lon: 7.4, hasNuclearWeapons: false),

        CountryTemplate(id: "San Marino", name: "San Marino", alignment: .western, governmentType: .democracy,
                       gdp: 1.5, population: 0.03, militaryStrength: 0, economicStrength: 2, lat: 43.9, lon: 12.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Vatican City", name: "Vatican City", alignment: .neutral, governmentType: .theocracy,
                       gdp: 0.5, population: 0.001, militaryStrength: 0, economicStrength: 1, lat: 41.9, lon: 12.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Malta", name: "Malta", alignment: .western, governmentType: .democracy,
                       gdp: 17.0, population: 0.5, militaryStrength: 5, economicStrength: 15, lat: 35.9, lon: 14.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Cyprus", name: "Cyprus", alignment: .western, governmentType: .democracy,
                       gdp: 28.0, population: 1.2, militaryStrength: 10, economicStrength: 20, lat: 35.1, lon: 33.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Luxembourg", name: "Luxembourg", alignment: .western, governmentType: .monarchy,
                       gdp: 85.0, population: 0.6, militaryStrength: 5, economicStrength: 40, lat: 49.6, lon: 6.1, hasNuclearWeapons: false),

        CountryTemplate(id: "Estonia", name: "Estonia", alignment: .western, governmentType: .democracy,
                       gdp: 38.0, population: 1.3, militaryStrength: 15, economicStrength: 25, lat: 59.4, lon: 24.7, hasNuclearWeapons: false),

        CountryTemplate(id: "Latvia", name: "Latvia", alignment: .western, governmentType: .democracy,
                       gdp: 42.0, population: 1.9, militaryStrength: 15, economicStrength: 28, lat: 56.9, lon: 24.1, hasNuclearWeapons: false),

        CountryTemplate(id: "Lithuania", name: "Lithuania", alignment: .western, governmentType: .democracy,
                       gdp: 67.0, population: 2.8, militaryStrength: 20, economicStrength: 35, lat: 55.2, lon: 23.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Moldova", name: "Moldova", alignment: .neutral, governmentType: .democracy,
                       gdp: 14.0, population: 2.6, militaryStrength: 10, economicStrength: 15, lat: 47.0, lon: 28.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Armenia", name: "Armenia", alignment: .russian, governmentType: .democracy,
                       gdp: 19.0, population: 3.0, militaryStrength: 25, economicStrength: 15, lat: 40.2, lon: 44.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Azerbaijan", name: "Azerbaijan", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 55.0, population: 10.1, militaryStrength: 40, economicStrength: 35, lat: 40.4, lon: 47.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Georgia", name: "Georgia", alignment: .western, governmentType: .democracy,
                       gdp: 24.0, population: 3.7, militaryStrength: 20, economicStrength: 20, lat: 42.3, lon: 43.4, hasNuclearWeapons: false),

        // Caribbean nations
        CountryTemplate(id: "Antigua and Barbuda", name: "Antigua and Barbuda", alignment: .western, governmentType: .democracy,
                       gdp: 1.8, population: 0.1, militaryStrength: 0, economicStrength: 2, lat: 17.1, lon: -61.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Bahamas", name: "Bahamas", alignment: .western, governmentType: .democracy,
                       gdp: 12.0, population: 0.4, militaryStrength: 0, economicStrength: 8, lat: 25.0, lon: -77.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Barbados", name: "Barbados", alignment: .western, governmentType: .democracy,
                       gdp: 5.4, population: 0.3, militaryStrength: 0, economicStrength: 5, lat: 13.2, lon: -59.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Belize", name: "Belize", alignment: .western, governmentType: .democracy,
                       gdp: 3.5, population: 0.4, militaryStrength: 5, economicStrength: 3, lat: 17.2, lon: -88.7, hasNuclearWeapons: false),

        CountryTemplate(id: "Dominica", name: "Dominica", alignment: .western, governmentType: .democracy,
                       gdp: 0.6, population: 0.07, militaryStrength: 0, economicStrength: 1, lat: 15.4, lon: -61.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Grenada", name: "Grenada", alignment: .western, governmentType: .democracy,
                       gdp: 1.2, population: 0.1, militaryStrength: 0, economicStrength: 1, lat: 12.1, lon: -61.7, hasNuclearWeapons: false),

        CountryTemplate(id: "Jamaica", name: "Jamaica", alignment: .western, governmentType: .democracy,
                       gdp: 16.0, population: 2.8, militaryStrength: 10, economicStrength: 12, lat: 18.1, lon: -77.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Saint Kitts and Nevis", name: "Saint Kitts and Nevis", alignment: .western, governmentType: .democracy,
                       gdp: 1.0, population: 0.05, militaryStrength: 0, economicStrength: 1, lat: 17.3, lon: -62.7, hasNuclearWeapons: false),

        CountryTemplate(id: "Saint Lucia", name: "Saint Lucia", alignment: .western, governmentType: .democracy,
                       gdp: 2.1, population: 0.2, militaryStrength: 0, economicStrength: 2, lat: 13.9, lon: -60.97, hasNuclearWeapons: false),

        CountryTemplate(id: "Saint Vincent and the Grenadines", name: "Saint Vincent and the Grenadines", alignment: .western, governmentType: .democracy,
                       gdp: 0.9, population: 0.1, militaryStrength: 0, economicStrength: 1, lat: 13.2, lon: -61.2, hasNuclearWeapons: false),

        CountryTemplate(id: "Trinidad and Tobago", name: "Trinidad and Tobago", alignment: .western, governmentType: .democracy,
                       gdp: 24.0, population: 1.4, militaryStrength: 10, economicStrength: 18, lat: 10.7, lon: -61.2, hasNuclearWeapons: false),

        // Central America additions
        CountryTemplate(id: "Nicaragua", name: "Nicaragua", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 15.0, population: 6.6, militaryStrength: 15, economicStrength: 10, lat: 12.9, lon: -85.2, hasNuclearWeapons: false),

        CountryTemplate(id: "Panama", name: "Panama", alignment: .western, governmentType: .democracy,
                       gdp: 77.0, population: 4.3, militaryStrength: 10, economicStrength: 45, lat: 8.5, lon: -80.8, hasNuclearWeapons: false),

        // South America additions
        CountryTemplate(id: "Paraguay", name: "Paraguay", alignment: .neutral, governmentType: .democracy,
                       gdp: 43.0, population: 7.2, militaryStrength: 20, economicStrength: 25, lat: -23.4, lon: -58.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Suriname", name: "Suriname", alignment: .western, governmentType: .democracy,
                       gdp: 3.6, population: 0.6, militaryStrength: 5, economicStrength: 3, lat: 3.9, lon: -56.0, hasNuclearWeapons: false),

        CountryTemplate(id: "Uruguay", name: "Uruguay", alignment: .western, governmentType: .democracy,
                       gdp: 67.0, population: 3.4, militaryStrength: 15, economicStrength: 40, lat: -32.5, lon: -55.8, hasNuclearWeapons: false),

        // African nations
        CountryTemplate(id: "Benin", name: "Benin", alignment: .neutral, governmentType: .democracy,
                       gdp: 19.0, population: 13.0, militaryStrength: 15, economicStrength: 12, lat: 9.3, lon: 2.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Botswana", name: "Botswana", alignment: .western, governmentType: .democracy,
                       gdp: 20.0, population: 2.4, militaryStrength: 10, economicStrength: 15, lat: -22.3, lon: 24.7, hasNuclearWeapons: false),

        CountryTemplate(id: "Burkina Faso", name: "Burkina Faso", alignment: .neutral, governmentType: .military,
                       gdp: 20.0, population: 22.0, militaryStrength: 20, economicStrength: 10, lat: 12.2, lon: -1.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Burundi", name: "Burundi", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 3.7, population: 12.5, militaryStrength: 15, economicStrength: 5, lat: -3.4, lon: 29.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Cabo Verde", name: "Cabo Verde", alignment: .western, governmentType: .democracy,
                       gdp: 2.1, population: 0.6, militaryStrength: 5, economicStrength: 3, lat: 16.0, lon: -24.0, hasNuclearWeapons: false),

        CountryTemplate(id: "Central African Republic", name: "Central African Republic", alignment: .neutral, governmentType: .unstable,
                       gdp: 2.5, population: 5.5, militaryStrength: 10, economicStrength: 2, lat: 6.6, lon: 20.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Chad", name: "Chad", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 13.0, population: 17.4, militaryStrength: 25, economicStrength: 8, lat: 15.5, lon: 19.0, hasNuclearWeapons: false),

        CountryTemplate(id: "Comoros", name: "Comoros", alignment: .neutral, governmentType: .democracy,
                       gdp: 1.3, population: 0.9, militaryStrength: 5, economicStrength: 2, lat: -11.6, lon: 43.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Congo", name: "Republic of the Congo", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 14.0, population: 5.8, militaryStrength: 15, economicStrength: 10, lat: -0.2, lon: 15.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Djibouti", name: "Djibouti", alignment: .western, governmentType: .authoritarian,
                       gdp: 3.6, population: 1.1, militaryStrength: 10, economicStrength: 5, lat: 11.8, lon: 42.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Equatorial Guinea", name: "Equatorial Guinea", alignment: .neutral, governmentType: .dictatorship,
                       gdp: 11.0, population: 1.7, militaryStrength: 10, economicStrength: 8, lat: 1.7, lon: 10.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Eritrea", name: "Eritrea", alignment: .neutral, governmentType: .dictatorship,
                       gdp: 2.6, population: 3.7, militaryStrength: 20, economicStrength: 3, lat: 15.2, lon: 39.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Eswatini", name: "Eswatini (Swaziland)", alignment: .neutral, governmentType: .monarchy,
                       gdp: 4.7, population: 1.2, militaryStrength: 5, economicStrength: 5, lat: -26.5, lon: 31.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Gabon", name: "Gabon", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 20.0, population: 2.3, militaryStrength: 15, economicStrength: 15, lat: -0.8, lon: 11.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Gambia", name: "The Gambia", alignment: .neutral, governmentType: .democracy,
                       gdp: 2.1, population: 2.6, militaryStrength: 5, economicStrength: 3, lat: 13.5, lon: -15.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Guinea", name: "Guinea", alignment: .neutral, governmentType: .military,
                       gdp: 18.0, population: 13.9, militaryStrength: 20, economicStrength: 12, lat: 9.9, lon: -9.7, hasNuclearWeapons: false),

        CountryTemplate(id: "Guinea-Bissau", name: "Guinea-Bissau", alignment: .neutral, governmentType: .unstable,
                       gdp: 1.9, population: 2.1, militaryStrength: 10, economicStrength: 2, lat: 11.8, lon: -15.2, hasNuclearWeapons: false),

        CountryTemplate(id: "Lesotho", name: "Lesotho", alignment: .neutral, governmentType: .monarchy,
                       gdp: 2.5, population: 2.3, militaryStrength: 5, economicStrength: 3, lat: -29.6, lon: 28.2, hasNuclearWeapons: false),

        CountryTemplate(id: "Liberia", name: "Liberia", alignment: .western, governmentType: .democracy,
                       gdp: 3.9, population: 5.3, militaryStrength: 10, economicStrength: 5, lat: 6.4, lon: -9.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Madagascar", name: "Madagascar", alignment: .neutral, governmentType: .democracy,
                       gdp: 15.0, population: 29.6, militaryStrength: 15, economicStrength: 10, lat: -18.8, lon: 47.0, hasNuclearWeapons: false),

        CountryTemplate(id: "Malawi", name: "Malawi", alignment: .neutral, governmentType: .democracy,
                       gdp: 13.0, population: 20.4, militaryStrength: 10, economicStrength: 8, lat: -13.3, lon: 34.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Mali", name: "Mali", alignment: .neutral, governmentType: .military,
                       gdp: 19.0, population: 22.6, militaryStrength: 20, economicStrength: 12, lat: 17.6, lon: -4.0, hasNuclearWeapons: false),

        CountryTemplate(id: "Mauritania", name: "Mauritania", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 10.0, population: 4.9, militaryStrength: 15, economicStrength: 8, lat: 21.0, lon: -10.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Mauritius", name: "Mauritius", alignment: .western, governmentType: .democracy,
                       gdp: 12.0, population: 1.3, militaryStrength: 0, economicStrength: 12, lat: -20.2, lon: 57.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Mozambique", name: "Mozambique", alignment: .neutral, governmentType: .democracy,
                       gdp: 17.0, population: 32.1, militaryStrength: 20, economicStrength: 12, lat: -18.7, lon: 35.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Namibia", name: "Namibia", alignment: .neutral, governmentType: .democracy,
                       gdp: 12.0, population: 2.6, militaryStrength: 10, economicStrength: 10, lat: -22.6, lon: 17.1, hasNuclearWeapons: false),

        CountryTemplate(id: "Niger", name: "Niger", alignment: .neutral, governmentType: .military,
                       gdp: 16.0, population: 26.2, militaryStrength: 20, economicStrength: 10, lat: 17.6, lon: 8.1, hasNuclearWeapons: false),

        CountryTemplate(id: "Rwanda", name: "Rwanda", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 13.0, population: 13.6, militaryStrength: 25, economicStrength: 10, lat: -1.9, lon: 29.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Sao Tome and Principe", name: "São Tomé and Príncipe", alignment: .neutral, governmentType: .democracy,
                       gdp: 0.5, population: 0.2, militaryStrength: 0, economicStrength: 1, lat: 0.2, lon: 6.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Senegal", name: "Senegal", alignment: .western, governmentType: .democracy,
                       gdp: 28.0, population: 17.7, militaryStrength: 20, economicStrength: 20, lat: 14.5, lon: -14.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Seychelles", name: "Seychelles", alignment: .western, governmentType: .democracy,
                       gdp: 1.7, population: 0.1, militaryStrength: 0, economicStrength: 3, lat: -4.7, lon: 55.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Sierra Leone", name: "Sierra Leone", alignment: .western, governmentType: .democracy,
                       gdp: 4.1, population: 8.6, militaryStrength: 10, economicStrength: 5, lat: 8.5, lon: -11.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Somalia", name: "Somalia", alignment: .neutral, governmentType: .failed,
                       gdp: 7.8, population: 17.6, militaryStrength: 10, economicStrength: 3, lat: 5.2, lon: 46.2, hasNuclearWeapons: false),

        CountryTemplate(id: "South Sudan", name: "South Sudan", alignment: .neutral, governmentType: .unstable,
                       gdp: 3.0, population: 11.4, militaryStrength: 15, economicStrength: 2, lat: 6.9, lon: 31.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Togo", name: "Togo", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 8.1, population: 8.8, militaryStrength: 10, economicStrength: 6, lat: 8.6, lon: 0.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Uganda", name: "Uganda", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 45.0, population: 48.6, militaryStrength: 30, economicStrength: 25, lat: 1.4, lon: 32.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Zambia", name: "Zambia", alignment: .neutral, governmentType: .democracy,
                       gdp: 26.0, population: 19.6, militaryStrength: 15, economicStrength: 18, lat: -13.1, lon: 27.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Zimbabwe", name: "Zimbabwe", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 25.0, population: 15.9, militaryStrength: 25, economicStrength: 15, lat: -19.0, lon: 29.2, hasNuclearWeapons: false),

        // Additional African nations
        CountryTemplate(id: "Tunisia", name: "Tunisia", alignment: .neutral, governmentType: .democracy,
                       gdp: 48.0, population: 12.0, militaryStrength: 30, economicStrength: 30, lat: 33.9, lon: 9.5, hasNuclearWeapons: false),

        // Middle East additions
        CountryTemplate(id: "Bahrain", name: "Bahrain", alignment: .western, governmentType: .monarchy,
                       gdp: 45.0, population: 1.5, militaryStrength: 20, economicStrength: 40, lat: 26.1, lon: 50.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Kuwait", name: "Kuwait", alignment: .western, governmentType: .monarchy,
                       gdp: 140.0, population: 4.3, militaryStrength: 35, economicStrength: 80, lat: 29.3, lon: 47.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Oman", name: "Oman", alignment: .western, governmentType: .monarchy,
                       gdp: 108.0, population: 4.6, militaryStrength: 40, economicStrength: 60, lat: 21.5, lon: 55.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Qatar", name: "Qatar", alignment: .western, governmentType: .monarchy,
                       gdp: 235.0, population: 2.7, militaryStrength: 30, economicStrength: 90, lat: 25.3, lon: 51.2, hasNuclearWeapons: false),

        CountryTemplate(id: "United Arab Emirates", name: "United Arab Emirates", alignment: .western, governmentType: .monarchy,
                       gdp: 508.0, population: 9.4, militaryStrength: 55, economicStrength: 85, lat: 23.4, lon: 53.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Yemen", name: "Yemen", alignment: .neutral, governmentType: .failed,
                       gdp: 21.0, population: 30.9, militaryStrength: 30, economicStrength: 8, lat: 15.6, lon: 48.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Lebanon", name: "Lebanon", alignment: .neutral, governmentType: .unstable,
                       gdp: 18.0, population: 5.5, militaryStrength: 25, economicStrength: 12, lat: 33.9, lon: 35.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Jordan", name: "Jordan", alignment: .western, governmentType: .monarchy,
                       gdp: 50.0, population: 11.1, militaryStrength: 40, economicStrength: 35, lat: 31.0, lon: 36.2, hasNuclearWeapons: false),

        // Central Asia
        CountryTemplate(id: "Kyrgyzstan", name: "Kyrgyzstan", alignment: .russian, governmentType: .authoritarian,
                       gdp: 11.0, population: 6.7, militaryStrength: 15, economicStrength: 8, lat: 41.2, lon: 74.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Tajikistan", name: "Tajikistan", alignment: .russian, governmentType: .authoritarian,
                       gdp: 11.0, population: 10.0, militaryStrength: 20, economicStrength: 8, lat: 38.9, lon: 71.3, hasNuclearWeapons: false),

        CountryTemplate(id: "Turkmenistan", name: "Turkmenistan", alignment: .neutral, governmentType: .dictatorship,
                       gdp: 53.0, population: 6.3, militaryStrength: 25, economicStrength: 35, lat: 38.9, lon: 59.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Uzbekistan", name: "Uzbekistan", alignment: .russian, governmentType: .authoritarian,
                       gdp: 80.0, population: 35.1, militaryStrength: 35, economicStrength: 45, lat: 41.4, lon: 64.6, hasNuclearWeapons: false),

        // South Asia additions
        CountryTemplate(id: "Nepal", name: "Nepal", alignment: .neutral, governmentType: .democracy,
                       gdp: 40.0, population: 30.0, militaryStrength: 25, economicStrength: 22, lat: 28.4, lon: 84.1, hasNuclearWeapons: false),

        CountryTemplate(id: "Bhutan", name: "Bhutan", alignment: .neutral, governmentType: .monarchy,
                       gdp: 3.0, population: 0.8, militaryStrength: 5, economicStrength: 3, lat: 27.5, lon: 90.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Sri Lanka", name: "Sri Lanka", alignment: .neutral, governmentType: .democracy,
                       gdp: 84.0, population: 22.2, militaryStrength: 30, economicStrength: 45, lat: 7.9, lon: 80.8, hasNuclearWeapons: false),

        CountryTemplate(id: "Maldives", name: "Maldives", alignment: .neutral, governmentType: .democracy,
                       gdp: 6.2, population: 0.5, militaryStrength: 0, economicStrength: 8, lat: 3.2, lon: 73.2, hasNuclearWeapons: false),

        // Southeast Asia additions
        CountryTemplate(id: "Laos", name: "Laos", alignment: .neutral, governmentType: .communist,
                       gdp: 21.0, population: 7.5, militaryStrength: 20, economicStrength: 15, lat: 19.9, lon: 102.5, hasNuclearWeapons: false),

        CountryTemplate(id: "Myanmar", name: "Myanmar (Burma)", alignment: .neutral, governmentType: .military,
                       gdp: 66.0, population: 54.8, militaryStrength: 50, economicStrength: 35, lat: 21.9, lon: 96.0, hasNuclearWeapons: false),

        CountryTemplate(id: "Cambodia", name: "Cambodia", alignment: .neutral, governmentType: .authoritarian,
                       gdp: 30.0, population: 16.9, militaryStrength: 25, economicStrength: 22, lat: 12.6, lon: 105.0, hasNuclearWeapons: false),

        CountryTemplate(id: "Brunei", name: "Brunei", alignment: .neutral, governmentType: .monarchy,
                       gdp: 14.0, population: 0.5, militaryStrength: 10, economicStrength: 25, lat: 4.5, lon: 114.7, hasNuclearWeapons: false),

        CountryTemplate(id: "Timor-Leste", name: "Timor-Leste (East Timor)", alignment: .western, governmentType: .democracy,
                       gdp: 3.0, population: 1.3, militaryStrength: 5, economicStrength: 3, lat: -8.9, lon: 125.7, hasNuclearWeapons: false),

        // Pacific Island Nations
        CountryTemplate(id: "Fiji", name: "Fiji", alignment: .neutral, governmentType: .democracy,
                       gdp: 5.5, population: 0.9, militaryStrength: 5, economicStrength: 6, lat: -17.7, lon: 178.1, hasNuclearWeapons: false),

        CountryTemplate(id: "Papua New Guinea", name: "Papua New Guinea", alignment: .western, governmentType: .democracy,
                       gdp: 28.0, population: 9.9, militaryStrength: 15, economicStrength: 18, lat: -6.3, lon: 143.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Solomon Islands", name: "Solomon Islands", alignment: .neutral, governmentType: .democracy,
                       gdp: 1.6, population: 0.7, militaryStrength: 0, economicStrength: 2, lat: -9.6, lon: 160.2, hasNuclearWeapons: false),

        CountryTemplate(id: "Vanuatu", name: "Vanuatu", alignment: .neutral, governmentType: .democracy,
                       gdp: 1.0, population: 0.3, militaryStrength: 0, economicStrength: 2, lat: -15.4, lon: 166.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Samoa", name: "Samoa", alignment: .neutral, governmentType: .democracy,
                       gdp: 0.9, population: 0.2, militaryStrength: 0, economicStrength: 2, lat: -13.8, lon: -172.1, hasNuclearWeapons: false),

        CountryTemplate(id: "Tonga", name: "Tonga", alignment: .western, governmentType: .monarchy,
                       gdp: 0.5, population: 0.1, militaryStrength: 0, economicStrength: 1, lat: -21.2, lon: -175.2, hasNuclearWeapons: false),

        CountryTemplate(id: "Kiribati", name: "Kiribati", alignment: .neutral, governmentType: .democracy,
                       gdp: 0.2, population: 0.1, militaryStrength: 0, economicStrength: 1, lat: 1.9, lon: -157.4, hasNuclearWeapons: false),

        CountryTemplate(id: "Marshall Islands", name: "Marshall Islands", alignment: .western, governmentType: .democracy,
                       gdp: 0.2, population: 0.06, militaryStrength: 0, economicStrength: 1, lat: 7.1, lon: 171.2, hasNuclearWeapons: false),

        CountryTemplate(id: "Micronesia", name: "Micronesia", alignment: .western, governmentType: .democracy,
                       gdp: 0.4, population: 0.1, militaryStrength: 0, economicStrength: 1, lat: 7.4, lon: 150.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Palau", name: "Palau", alignment: .western, governmentType: .democracy,
                       gdp: 0.3, population: 0.02, militaryStrength: 0, economicStrength: 2, lat: 7.5, lon: 134.6, hasNuclearWeapons: false),

        CountryTemplate(id: "Nauru", name: "Nauru", alignment: .neutral, governmentType: .democracy,
                       gdp: 0.1, population: 0.01, militaryStrength: 0, economicStrength: 1, lat: -0.5, lon: 166.9, hasNuclearWeapons: false),

        CountryTemplate(id: "Tuvalu", name: "Tuvalu", alignment: .neutral, governmentType: .democracy,
                       gdp: 0.06, population: 0.01, militaryStrength: 0, economicStrength: 1, lat: -7.1, lon: 177.6, hasNuclearWeapons: false),

        // Additional nations
        CountryTemplate(id: "Mongolia", name: "Mongolia", alignment: .neutral, governmentType: .democracy,
                       gdp: 18.0, population: 3.4, militaryStrength: 15, economicStrength: 12, lat: 46.9, lon: 103.8, hasNuclearWeapons: false)
    ]
}
