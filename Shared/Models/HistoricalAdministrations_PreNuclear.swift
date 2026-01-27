//
//  HistoricalAdministrations_PreNuclear.swift
//  Global Thermal Nuclear War
//
//  Historical US Presidents and Cabinets from 1789-1945
//  Pre-Nuclear Age Administrations
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

// MARK: - Pre-Nuclear Administrations Extension

extension Advisor {
    /// Get all pre-nuclear age administrations (1789-1945) - 32 presidents
    static func preNuclearAdministrations() -> [Administration] {
        return [
            // Founding Era (1789-1829)
            washingtonAdministration(),
            adamsAdministration(),
            jeffersonAdministration(),
            madisonAdministration(),
            monroeAdministration(),
            jqAdamsAdministration(),

            // Jacksonian Era (1829-1861)
            jacksonAdministration(),
            vanBurenAdministration(),
            harrisonAdministration(),
            tylerAdministration(),
            polkAdministration(),
            taylorAdministration(),
            fillmoreAdministration(),
            pierceAdministration(),
            buchananAdministration(),

            // Civil War Era (1861-1877)
            lincolnAdministration(),
            ajohnsonAdministration(),
            grantAdministration(),

            // Gilded Age (1877-1901)
            hayesAdministration(),
            garfieldAdministration(),
            arthurAdministration(),
            clevelandFirstAdministration(),
            harrisonBenjaminAdministration(),
            clevelandSecondAdministration(),
            mckinleyAdministration(),

            // Progressive Era (1901-1921)
            trooseveltAdministration(),
            taftAdministration(),
            wilsonAdministration(),

            // Roaring 20s & Depression (1921-1945)
            hardingAdministration(),
            coolidgeAdministration(),
            hooverAdministration(),
            fdrooseveltAdministration()
        ]
    }

    // MARK: - George Washington Administration (1789-1797)

    static func washingtonAdministration() -> Administration {
        Administration(
            id: "washington",
            name: "Washington Administration",
            president: "George Washington",
            years: "1789-1797",
            startYear: 1789,
            endYear: 1797,
            party: "None (Federalist-leaning)",
            advisors: [
                Advisor(
                    id: "washington",
                    name: "George Washington",
                    title: "President",
                    department: "Executive Office",
                    bio: "1st President, Father of the Nation, Commander-in-Chief during Revolution",
                    expertise: 95,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 95,
                    hawkishness: 50,
                    interventionism: 30,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy, .militaryStrike],
                    currentAdvice: "We must avoid foreign entanglements while building our strength.",
                    adviceType: .diplomatic,
                    portraitColor: "#8B4513"
                ),
                Advisor(
                    id: "jefferson_sec",
                    name: "Thomas Jefferson",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Principal author of Declaration of Independence, Francophile",
                    expertise: 90,
                    loyalty: 75,
                    influence: 85,
                    publicSupport: 80,
                    hawkishness: 30,
                    interventionism: 25,
                    fiscalConservatism: 80,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "We must support France, our Revolutionary ally.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "hamilton",
                    name: "Alexander Hamilton",
                    title: "Secretary of Treasury",
                    department: "Treasury",
                    bio: "Financial genius, Federalist leader, Pro-British",
                    expertise: 100,
                    loyalty: 90,
                    influence: 90,
                    publicSupport: 60,
                    hawkishness: 60,
                    interventionism: 50,
                    fiscalConservatism: 40,
                    adviceAreas: [.economicAid, .economicSanctions],
                    currentAdvice: "A strong federal government and British trade will secure our prosperity.",
                    adviceType: .economic,
                    portraitColor: "#DAA520"
                ),
                Advisor(
                    id: "knox",
                    name: "Henry Knox",
                    title: "Secretary of War",
                    department: "War",
                    bio: "Revolutionary War general, Artillery commander",
                    expertise: 80,
                    loyalty: 95,
                    influence: 70,
                    publicSupport: 70,
                    hawkishness: 55,
                    interventionism: 40,
                    fiscalConservatism: 65,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "Our military must remain strong but measured.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }

    // MARK: - John Adams Administration (1797-1801)

    static func adamsAdministration() -> Administration {
        Administration(
            id: "adams",
            name: "Adams Administration",
            president: "John Adams",
            years: "1797-1801",
            startYear: 1797,
            endYear: 1801,
            party: "Federalist",
            advisors: [
                Advisor(
                    id: "adams",
                    name: "John Adams",
                    title: "President",
                    department: "Executive Office",
                    bio: "2nd President, Founding Father, Avoided war with France",
                    expertise: 85,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 60,
                    hawkishness: 50,
                    interventionism: 40,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Peace with France at almost any cost, but maintain naval strength.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "pickering",
                    name: "Timothy Pickering",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Aggressive Federalist, Advocated war with France",
                    expertise: 70,
                    loyalty: 65,
                    influence: 70,
                    publicSupport: 55,
                    hawkishness: 85,
                    interventionism: 75,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .diplomacy],
                    currentAdvice: "France insults us daily. We must respond with force!",
                    adviceType: .military,
                    portraitColor: "#DC143C"
                )
            ]
        )
    }

    // MARK: - Thomas Jefferson Administration (1801-1809)

    static func jeffersonAdministration() -> Administration {
        Administration(
            id: "jefferson",
            name: "Jefferson Administration",
            president: "Thomas Jefferson",
            years: "1801-1809",
            startYear: 1801,
            endYear: 1809,
            party: "Democratic-Republican",
            advisors: [
                Advisor(
                    id: "jefferson",
                    name: "Thomas Jefferson",
                    title: "President",
                    department: "Executive Office",
                    bio: "3rd President, Authored Declaration of Independence, Louisiana Purchase",
                    expertise: 90,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 80,
                    hawkishness: 30,
                    interventionism: 25,
                    fiscalConservatism: 85,
                    adviceAreas: [.diplomacy, .economicSanctions],
                    currentAdvice: "Economic pressure, not war, will secure our rights.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "madison_sec",
                    name: "James Madison",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Father of the Constitution, Jefferson's closest ally",
                    expertise: 95,
                    loyalty: 95,
                    influence: 90,
                    publicSupport: 75,
                    hawkishness: 35,
                    interventionism: 30,
                    fiscalConservatism: 80,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Neutrality and trade will build our prosperity.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "gallatin",
                    name: "Albert Gallatin",
                    title: "Secretary of Treasury",
                    department: "Treasury",
                    bio: "Financial reformer, Reduced national debt",
                    expertise: 90,
                    loyalty: 90,
                    influence: 80,
                    publicSupport: 70,
                    hawkishness: 20,
                    interventionism: 20,
                    fiscalConservatism: 95,
                    adviceAreas: [.economicAid],
                    currentAdvice: "We must pay down debt and avoid expensive wars.",
                    adviceType: .economic,
                    portraitColor: "#DAA520"
                )
            ]
        )
    }

    // MARK: - James Madison Administration (1809-1817)

    static func madisonAdministration() -> Administration {
        Administration(
            id: "madison",
            name: "Madison Administration",
            president: "James Madison",
            years: "1809-1817",
            startYear: 1809,
            endYear: 1817,
            party: "Democratic-Republican",
            advisors: [
                Advisor(
                    id: "madison",
                    name: "James Madison",
                    title: "President",
                    department: "Executive Office",
                    bio: "4th President, Led nation through War of 1812, Father of Constitution",
                    expertise: 90,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 65,
                    hawkishness: 45,
                    interventionism: 40,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy, .militaryStrike],
                    currentAdvice: "British impressment of our sailors cannot stand.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "monroe_sec",
                    name: "James Monroe",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Future president, Negotiated Louisiana Purchase",
                    expertise: 85,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 75,
                    hawkishness: 50,
                    interventionism: 45,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "We must assert our sovereignty against British interference.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - James Monroe Administration (1817-1825)

    static func monroeAdministration() -> Administration {
        Administration(
            id: "monroe",
            name: "Monroe Administration",
            president: "James Monroe",
            years: "1817-1825",
            startYear: 1817,
            endYear: 1825,
            party: "Democratic-Republican",
            advisors: [
                Advisor(
                    id: "monroe",
                    name: "James Monroe",
                    title: "President",
                    department: "Executive Office",
                    bio: "5th President, Monroe Doctrine author, 'Era of Good Feelings'",
                    expertise: 85,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 85,
                    hawkishness: 45,
                    interventionism: 35,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "European powers must stay out of the Americas. This hemisphere is ours.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "jq_adams_sec",
                    name: "John Quincy Adams",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Brilliant diplomat, Architect of Monroe Doctrine",
                    expertise: 95,
                    loyalty: 85,
                    influence: 90,
                    publicSupport: 70,
                    hawkishness: 40,
                    interventionism: 35,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "America goes not abroad in search of monsters to destroy.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - John Quincy Adams Administration (1825-1829)

    static func jqAdamsAdministration() -> Administration {
        Administration(
            id: "jq_adams",
            name: "J.Q. Adams Administration",
            president: "John Quincy Adams",
            years: "1825-1829",
            startYear: 1825,
            endYear: 1829,
            party: "Democratic-Republican",
            advisors: [
                Advisor(
                    id: "jq_adams",
                    name: "John Quincy Adams",
                    title: "President",
                    department: "Executive Office",
                    bio: "6th President, Son of John Adams, Brilliant diplomat",
                    expertise: 95,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 50,
                    hawkishness: 40,
                    interventionism: 30,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Internal improvements will strengthen the nation more than foreign wars.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "clay",
                    name: "Henry Clay",
                    title: "Secretary of State",
                    department: "State",
                    bio: "The Great Compromiser, Presidential candidate",
                    expertise: 90,
                    loyalty: 80,
                    influence: 85,
                    publicSupport: 75,
                    hawkishness: 45,
                    interventionism: 40,
                    fiscalConservatism: 65,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "The American System will make us independent and prosperous.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Andrew Jackson Administration (1829-1837)

    static func jacksonAdministration() -> Administration {
        Administration(
            id: "jackson",
            name: "Jackson Administration",
            president: "Andrew Jackson",
            years: "1829-1837",
            startYear: 1829,
            endYear: 1837,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "jackson",
                    name: "Andrew Jackson",
                    title: "President",
                    department: "Executive Office",
                    bio: "7th President, War hero, 'Old Hickory', Populist firebrand",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 75,
                    hawkishness: 80,
                    interventionism: 60,
                    fiscalConservatism: 85,
                    adviceAreas: [.militaryStrike, .covertOps],
                    currentAdvice: "By the Eternal! I will defend this nation's honor with force if needed.",
                    adviceType: .military,
                    portraitColor: "#8B0000"
                ),
                Advisor(
                    id: "van_buren_sec",
                    name: "Martin Van Buren",
                    title: "Secretary of State",
                    department: "State",
                    bio: "The Little Magician, Master political operator",
                    expertise: 80,
                    loyalty: 85,
                    influence: 75,
                    publicSupport: 65,
                    hawkishness: 40,
                    interventionism: 35,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy, .covertOps],
                    currentAdvice: "Political maneuvering can achieve what force cannot.",
                    adviceType: .covert,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - Martin Van Buren Administration (1837-1841)

    static func vanBurenAdministration() -> Administration {
        Administration(
            id: "van_buren",
            name: "Van Buren Administration",
            president: "Martin Van Buren",
            years: "1837-1841",
            startYear: 1837,
            endYear: 1841,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "van_buren",
                    name: "Martin Van Buren",
                    title: "President",
                    department: "Executive Office",
                    bio: "8th President, Political strategist, Faced Panic of 1837",
                    expertise: 80,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 45,
                    hawkishness: 35,
                    interventionism: 30,
                    fiscalConservatism: 80,
                    adviceAreas: [.diplomacy, .economicSanctions],
                    currentAdvice: "We must weather this economic storm without foreign entanglements.",
                    adviceType: .economic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - William Henry Harrison Administration (1841)

    static func harrisonAdministration() -> Administration {
        Administration(
            id: "harrison",
            name: "Harrison Administration",
            president: "William Henry Harrison",
            years: "1841",
            startYear: 1841,
            endYear: 1841,
            party: "Whig",
            advisors: [
                Advisor(
                    id: "harrison",
                    name: "William Henry Harrison",
                    title: "President",
                    department: "Executive Office",
                    bio: "9th President, War hero, Died after 31 days in office",
                    expertise: 70,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 70,
                    hawkishness: 60,
                    interventionism: 50,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "Tippecanoe and Tyler too!",
                    adviceType: .military,
                    portraitColor: "#8B4513"
                )
            ]
        )
    }

    // MARK: - John Tyler Administration (1841-1845)

    static func tylerAdministration() -> Administration {
        Administration(
            id: "tyler",
            name: "Tyler Administration",
            president: "John Tyler",
            years: "1841-1845",
            startYear: 1841,
            endYear: 1845,
            party: "Whig (expelled)",
            advisors: [
                Advisor(
                    id: "tyler",
                    name: "John Tyler",
                    title: "President",
                    department: "Executive Office",
                    bio: "10th President, 'His Accidency', Annexed Texas",
                    expertise: 70,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 45,
                    hawkishness: 55,
                    interventionism: 60,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Texas must join the Union, whatever the cost.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "webster",
                    name: "Daniel Webster",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Great orator, Nationalist, Treaty negotiator",
                    expertise: 90,
                    loyalty: 70,
                    influence: 85,
                    publicSupport: 80,
                    hawkishness: 40,
                    interventionism: 35,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Liberty and Union, now and forever, one and inseparable!",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - James K. Polk Administration (1845-1849)

    static func polkAdministration() -> Administration {
        Administration(
            id: "polk",
            name: "Polk Administration",
            president: "James K. Polk",
            years: "1845-1849",
            startYear: 1845,
            endYear: 1849,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "polk",
                    name: "James K. Polk",
                    title: "President",
                    department: "Executive Office",
                    bio: "11th President, Manifest Destiny champion, Acquired California and Southwest",
                    expertise: 85,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 70,
                    hawkishness: 75,
                    interventionism: 80,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .diplomacy],
                    currentAdvice: "Our destiny is to span from sea to shining sea.",
                    adviceType: .military,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "buchanan_sec",
                    name: "James Buchanan",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Future president, Negotiated with Britain over Oregon",
                    expertise: 80,
                    loyalty: 85,
                    influence: 75,
                    publicSupport: 65,
                    hawkishness: 50,
                    interventionism: 55,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Negotiate with Britain, but be prepared for war over Oregon.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Zachary Taylor Administration (1849-1850)

    static func taylorAdministration() -> Administration {
        Administration(
            id: "taylor",
            name: "Taylor Administration",
            president: "Zachary Taylor",
            years: "1849-1850",
            startYear: 1849,
            endYear: 1850,
            party: "Whig",
            advisors: [
                Advisor(
                    id: "taylor",
                    name: "Zachary Taylor",
                    title: "President",
                    department: "Executive Office",
                    bio: "12th President, Mexican-American War hero, Died in office",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 65,
                    hawkishness: 70,
                    interventionism: 55,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "I will use force to preserve the Union if needed.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }

    // MARK: - Millard Fillmore Administration (1850-1853)

    static func fillmoreAdministration() -> Administration {
        Administration(
            id: "fillmore",
            name: "Fillmore Administration",
            president: "Millard Fillmore",
            years: "1850-1853",
            startYear: 1850,
            endYear: 1853,
            party: "Whig",
            advisors: [
                Advisor(
                    id: "fillmore",
                    name: "Millard Fillmore",
                    title: "President",
                    department: "Executive Office",
                    bio: "13th President, Compromise of 1850, Opened trade with Japan",
                    expertise: 70,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 50,
                    hawkishness: 45,
                    interventionism: 50,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Compromise will preserve the Union longer than force.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - Franklin Pierce Administration (1853-1857)

    static func pierceAdministration() -> Administration {
        Administration(
            id: "pierce",
            name: "Pierce Administration",
            president: "Franklin Pierce",
            years: "1853-1857",
            startYear: 1853,
            endYear: 1857,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "pierce",
                    name: "Franklin Pierce",
                    title: "President",
                    department: "Executive Office",
                    bio: "14th President, Pro-expansion, Kansas-Nebraska Act disaster",
                    expertise: 60,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 35,
                    hawkishness: 60,
                    interventionism: 70,
                    fiscalConservatism: 65,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Expansion will unite the nation... I hope.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - James Buchanan Administration (1857-1861)

    static func buchananAdministration() -> Administration {
        Administration(
            id: "buchanan",
            name: "Buchanan Administration",
            president: "James Buchanan",
            years: "1857-1861",
            startYear: 1857,
            endYear: 1861,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "buchanan",
                    name: "James Buchanan",
                    title: "President",
                    department: "Executive Office",
                    bio: "15th President, Presided over nation splitting apart, Often ranked worst president",
                    expertise: 65,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 25,
                    hawkishness: 35,
                    interventionism: 30,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Perhaps if we do nothing, this crisis will resolve itself...",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - Abraham Lincoln Administration (1861-1865)

    static func lincolnAdministration() -> Administration {
        Administration(
            id: "lincoln",
            name: "Lincoln Administration",
            president: "Abraham Lincoln",
            years: "1861-1865",
            startYear: 1861,
            endYear: 1865,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "lincoln",
                    name: "Abraham Lincoln",
                    title: "President",
                    department: "Executive Office",
                    bio: "16th President, Preserved the Union, Emancipation Proclamation, Assassinated 1865",
                    expertise: 100,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 55,
                    hawkishness: 70,
                    interventionism: 90,
                    fiscalConservatism: 60,
                    adviceAreas: [.militaryStrike, .diplomacy],
                    currentAdvice: "A house divided against itself cannot stand. The Union must be preserved.",
                    adviceType: .military,
                    portraitColor: "#8B4513"
                ),
                Advisor(
                    id: "seward",
                    name: "William H. Seward",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Master diplomat, Prevented European intervention in Civil War",
                    expertise: 95,
                    loyalty: 90,
                    influence: 90,
                    publicSupport: 70,
                    hawkishness: 60,
                    interventionism: 65,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Keep Britain and France neutral at all costs.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "stanton",
                    name: "Edwin M. Stanton",
                    title: "Secretary of War",
                    department: "War",
                    bio: "Ruthless administrator, Organized Union war effort",
                    expertise: 90,
                    loyalty: 95,
                    influence: 85,
                    publicSupport: 50,
                    hawkishness: 85,
                    interventionism: 90,
                    fiscalConservatism: 65,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "Total war is necessary. The rebellion must be crushed.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                ),
                Advisor(
                    id: "grant_general",
                    name: "Ulysses S. Grant",
                    title: "General-in-Chief",
                    department: "War",
                    bio: "Commanding General, Future president, Unconditional Surrender Grant",
                    expertise: 95,
                    loyalty: 100,
                    influence: 90,
                    publicSupport: 85,
                    hawkishness: 80,
                    interventionism: 85,
                    fiscalConservatism: 65,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "Fight it out on this line if it takes all summer.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }

    // MARK: - Andrew Johnson Administration (1865-1869)

    static func ajohnsonAdministration() -> Administration {
        Administration(
            id: "a_johnson",
            name: "Andrew Johnson Administration",
            president: "Andrew Johnson",
            years: "1865-1869",
            startYear: 1865,
            endYear: 1869,
            party: "National Union/Democratic",
            advisors: [
                Advisor(
                    id: "a_johnson",
                    name: "Andrew Johnson",
                    title: "President",
                    department: "Executive Office",
                    bio: "17th President, Assumed office after Lincoln assassination, Impeached but acquitted",
                    expertise: 60,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 30,
                    hawkishness: 50,
                    interventionism: 45,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "The South must be restored, not punished.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "seward_cont",
                    name: "William H. Seward",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Continued from Lincoln, Purchased Alaska ('Seward's Folly')",
                    expertise: 95,
                    loyalty: 75,
                    influence: 80,
                    publicSupport: 70,
                    hawkishness: 55,
                    interventionism: 60,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Alaska will be vital to our Pacific expansion.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Ulysses S. Grant Administration (1869-1877)

    static func grantAdministration() -> Administration {
        Administration(
            id: "grant",
            name: "Grant Administration",
            president: "Ulysses S. Grant",
            years: "1869-1877",
            startYear: 1869,
            endYear: 1877,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "grant",
                    name: "Ulysses S. Grant",
                    title: "President",
                    department: "Executive Office",
                    bio: "18th President, Civil War hero, Reconstruction enforcer, Corruption scandals",
                    expertise: 85,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 60,
                    hawkishness: 70,
                    interventionism: 75,
                    fiscalConservatism: 60,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "The Union victory must be secured through Reconstruction.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                ),
                Advisor(
                    id: "fish",
                    name: "Hamilton Fish",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Skilled diplomat, Settled Alabama Claims with Britain",
                    expertise: 90,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 75,
                    hawkishness: 40,
                    interventionism: 45,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Peaceful arbitration with Britain will strengthen both nations.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Rutherford B. Hayes Administration (1877-1881)

    static func hayesAdministration() -> Administration {
        Administration(
            id: "hayes",
            name: "Hayes Administration",
            president: "Rutherford B. Hayes",
            years: "1877-1881",
            startYear: 1877,
            endYear: 1881,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "hayes",
                    name: "Rutherford B. Hayes",
                    title: "President",
                    department: "Executive Office",
                    bio: "19th President, Ended Reconstruction, Disputed election",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 50,
                    hawkishness: 45,
                    interventionism: 40,
                    fiscalConservatism: 80,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "We must reconcile North and South.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - James A. Garfield Administration (1881)

    static func garfieldAdministration() -> Administration {
        Administration(
            id: "garfield",
            name: "Garfield Administration",
            president: "James A. Garfield",
            years: "1881",
            startYear: 1881,
            endYear: 1881,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "garfield",
                    name: "James A. Garfield",
                    title: "President",
                    department: "Executive Office",
                    bio: "20th President, Assassinated after 6 months, Civil service reformer",
                    expertise: 80,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 70,
                    hawkishness: 50,
                    interventionism: 45,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Merit, not patronage, should govern appointments.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - Chester A. Arthur Administration (1881-1885)

    static func arthurAdministration() -> Administration {
        Administration(
            id: "arthur",
            name: "Arthur Administration",
            president: "Chester A. Arthur",
            years: "1881-1885",
            startYear: 1881,
            endYear: 1885,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "arthur",
                    name: "Chester A. Arthur",
                    title: "President",
                    department: "Executive Office",
                    bio: "21st President, Assumed after Garfield assassination, Reformed civil service",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 65,
                    hawkishness: 50,
                    interventionism: 45,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "I will not be a party puppet. Reform is needed.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - Grover Cleveland First Administration (1885-1889)

    static func clevelandFirstAdministration() -> Administration {
        Administration(
            id: "cleveland_first",
            name: "Cleveland First Administration",
            president: "Grover Cleveland",
            years: "1885-1889",
            startYear: 1885,
            endYear: 1889,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "cleveland",
                    name: "Grover Cleveland",
                    title: "President",
                    department: "Executive Office",
                    bio: "22nd President, Only president to serve non-consecutive terms, Anti-imperialism",
                    expertise: 80,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 70,
                    hawkishness: 35,
                    interventionism: 25,
                    fiscalConservatism: 90,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "We should not seek empire. Isolationism serves us best.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - Benjamin Harrison Administration (1889-1893)

    static func harrisonBenjaminAdministration() -> Administration {
        Administration(
            id: "harrison_benjamin",
            name: "B. Harrison Administration",
            president: "Benjamin Harrison",
            years: "1889-1893",
            startYear: 1889,
            endYear: 1893,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "harrison_benjamin",
                    name: "Benjamin Harrison",
                    title: "President",
                    department: "Executive Office",
                    bio: "23rd President, Grandson of W.H. Harrison, Expanded Navy",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 60,
                    hawkishness: 60,
                    interventionism: 55,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "A strong Navy will protect our commerce and interests.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }

    // MARK: - Grover Cleveland Second Administration (1893-1897)

    static func clevelandSecondAdministration() -> Administration {
        Administration(
            id: "cleveland_second",
            name: "Cleveland Second Administration",
            president: "Grover Cleveland",
            years: "1893-1897",
            startYear: 1893,
            endYear: 1897,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "cleveland",
                    name: "Grover Cleveland",
                    title: "President",
                    department: "Executive Office",
                    bio: "24th President, Same man as 22nd, Opposed annexation of Hawaii",
                    expertise: 85,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 55,
                    hawkishness: 35,
                    interventionism: 25,
                    fiscalConservatism: 90,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "America should not become a colonial empire.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                )
            ]
        )
    }

    // MARK: - William McKinley Administration (1897-1901)

    static func mckinleyAdministration() -> Administration {
        Administration(
            id: "mckinley",
            name: "McKinley Administration",
            president: "William McKinley",
            years: "1897-1901",
            startYear: 1897,
            endYear: 1901,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "mckinley",
                    name: "William McKinley",
                    title: "President",
                    department: "Executive Office",
                    bio: "25th President, Spanish-American War, Acquired Philippines, Assassinated 1901",
                    expertise: 80,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 75,
                    hawkishness: 60,
                    interventionism: 70,
                    fiscalConservatism: 75,
                    adviceAreas: [.militaryStrike, .diplomacy],
                    currentAdvice: "Remember the Maine! Spain must answer for its crimes.",
                    adviceType: .military,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "hay",
                    name: "John Hay",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Open Door Policy in China, Negotiated Panama Canal",
                    expertise: 90,
                    loyalty: 90,
                    influence: 85,
                    publicSupport: 75,
                    hawkishness: 55,
                    interventionism: 65,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "A splendid little war with Spain will establish us as a world power.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "t_roosevelt_asst",
                    name: "Theodore Roosevelt",
                    title: "Assistant Secretary of Navy",
                    department: "Navy",
                    bio: "Future president, War hawk, Rough Rider",
                    expertise: 85,
                    loyalty: 85,
                    influence: 75,
                    publicSupport: 80,
                    hawkishness: 90,
                    interventionism: 85,
                    fiscalConservatism: 65,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "Speak softly and carry a big stick... but sometimes don't speak softly!",
                    adviceType: .military,
                    portraitColor: "#8B4513"
                )
            ]
        )
    }

    // MARK: - Theodore Roosevelt Administration (1901-1909)

    static func trooseveltAdministration() -> Administration {
        Administration(
            id: "t_roosevelt",
            name: "T. Roosevelt Administration",
            president: "Theodore Roosevelt",
            years: "1901-1909",
            startYear: 1901,
            endYear: 1909,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "t_roosevelt",
                    name: "Theodore Roosevelt",
                    title: "President",
                    department: "Executive Office",
                    bio: "26th President, Big Stick Diplomacy, Panama Canal, Nobel Peace Prize",
                    expertise: 95,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 85,
                    hawkishness: 80,
                    interventionism: 80,
                    fiscalConservatism: 65,
                    adviceAreas: [.militaryStrike, .diplomacy, .covertOps],
                    currentAdvice: "Walk softly and carry a big stick; you will go far.",
                    adviceType: .military,
                    portraitColor: "#8B4513"
                ),
                Advisor(
                    id: "root",
                    name: "Elihu Root",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Nobel Peace Prize, Reorganized State Department",
                    expertise: 95,
                    loyalty: 90,
                    influence: 90,
                    publicSupport: 75,
                    hawkishness: 65,
                    interventionism: 70,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy, .militaryStrike],
                    currentAdvice: "American power must be organized and disciplined.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "taft_sec",
                    name: "William Howard Taft",
                    title: "Secretary of War",
                    department: "War",
                    bio: "Future president, Governor of Philippines",
                    expertise: 85,
                    loyalty: 95,
                    influence: 80,
                    publicSupport: 70,
                    hawkishness: 55,
                    interventionism: 65,
                    fiscalConservatism: 75,
                    adviceAreas: [.militaryStrike],
                    currentAdvice: "We must civilize the Philippines through firm but fair governance.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }

    // MARK: - William Howard Taft Administration (1909-1913)

    static func taftAdministration() -> Administration {
        Administration(
            id: "taft",
            name: "Taft Administration",
            president: "William Howard Taft",
            years: "1909-1913",
            startYear: 1909,
            endYear: 1913,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "taft",
                    name: "William Howard Taft",
                    title: "President",
                    department: "Executive Office",
                    bio: "27th President, Dollar Diplomacy, Later Chief Justice",
                    expertise: 85,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 60,
                    hawkishness: 50,
                    interventionism: 60,
                    fiscalConservatism: 80,
                    adviceAreas: [.economicAid, .diplomacy],
                    currentAdvice: "Dollars, not bullets, will secure American interests abroad.",
                    adviceType: .economic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "knox_sec",
                    name: "Philander C. Knox",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Corporate lawyer, Architect of Dollar Diplomacy",
                    expertise: 85,
                    loyalty: 85,
                    influence: 80,
                    publicSupport: 60,
                    hawkishness: 45,
                    interventionism: 65,
                    fiscalConservatism: 85,
                    adviceAreas: [.economicAid, .diplomacy],
                    currentAdvice: "American banks will civilize Latin America better than soldiers.",
                    adviceType: .economic,
                    portraitColor: "#DAA520"
                )
            ]
        )
    }

    // MARK: - Woodrow Wilson Administration (1913-1921)

    static func wilsonAdministration() -> Administration {
        Administration(
            id: "wilson",
            name: "Wilson Administration",
            president: "Woodrow Wilson",
            years: "1913-1921",
            startYear: 1913,
            endYear: 1921,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "wilson",
                    name: "Woodrow Wilson",
                    title: "President",
                    department: "Executive Office",
                    bio: "28th President, Led US into WW1, League of Nations advocate, Nobel Peace Prize",
                    expertise: 90,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 70,
                    hawkishness: 60,
                    interventionism: 75,
                    fiscalConservatism: 65,
                    adviceAreas: [.diplomacy, .militaryStrike, .treaties],
                    currentAdvice: "The world must be made safe for democracy.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "lansing",
                    name: "Robert Lansing",
                    title: "Secretary of State",
                    department: "State",
                    bio: "International lawyer, Managed WW1 diplomacy",
                    expertise: 90,
                    loyalty: 80,
                    influence: 75,
                    publicSupport: 65,
                    hawkishness: 70,
                    interventionism: 75,
                    fiscalConservatism: 70,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "Germany's submarine warfare demands American intervention.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Warren G. Harding Administration (1921-1923)

    static func hardingAdministration() -> Administration {
        Administration(
            id: "harding",
            name: "Harding Administration",
            president: "Warren G. Harding",
            years: "1921-1923",
            startYear: 1921,
            endYear: 1923,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "harding",
                    name: "Warren G. Harding",
                    title: "President",
                    department: "Executive Office",
                    bio: "29th President, Return to normalcy, Died in office amid scandals",
                    expertise: 60,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 65,
                    hawkishness: 40,
                    interventionism: 30,
                    fiscalConservatism: 80,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "America needs healing, not foreign adventures.",
                    adviceType: .diplomatic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "hoover_sec",
                    name: "Herbert Hoover",
                    title: "Secretary of Commerce",
                    department: "Commerce",
                    bio: "Future president, Humanitarian, Efficient administrator",
                    expertise: 90,
                    loyalty: 85,
                    influence: 80,
                    publicSupport: 85,
                    hawkishness: 35,
                    interventionism: 40,
                    fiscalConservatism: 85,
                    adviceAreas: [.economicAid],
                    currentAdvice: "American industry will lead the world through cooperation.",
                    adviceType: .economic,
                    portraitColor: "#DAA520"
                )
            ]
        )
    }

    // MARK: - Calvin Coolidge Administration (1923-1929)

    static func coolidgeAdministration() -> Administration {
        Administration(
            id: "coolidge",
            name: "Coolidge Administration",
            president: "Calvin Coolidge",
            years: "1923-1929",
            startYear: 1923,
            endYear: 1929,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "coolidge",
                    name: "Calvin Coolidge",
                    title: "President",
                    department: "Executive Office",
                    bio: "30th President, Silent Cal, Pro-business, Roaring Twenties prosperity",
                    expertise: 75,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 75,
                    hawkishness: 30,
                    interventionism: 25,
                    fiscalConservatism: 95,
                    adviceAreas: [.economicSanctions],
                    currentAdvice: "The business of America is business.",
                    adviceType: .economic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "kellogg",
                    name: "Frank B. Kellogg",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Nobel Peace Prize, Kellogg-Briand Pact outlawing war",
                    expertise: 85,
                    loyalty: 90,
                    influence: 80,
                    publicSupport: 70,
                    hawkishness: 25,
                    interventionism: 30,
                    fiscalConservatism: 80,
                    adviceAreas: [.treaties, .diplomacy],
                    currentAdvice: "War can be outlawed through international agreement.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Herbert Hoover Administration (1929-1933)

    static func hooverAdministration() -> Administration {
        Administration(
            id: "hoover",
            name: "Hoover Administration",
            president: "Herbert Hoover",
            years: "1929-1933",
            startYear: 1929,
            endYear: 1933,
            party: "Republican",
            advisors: [
                Advisor(
                    id: "hoover",
                    name: "Herbert Hoover",
                    title: "President",
                    department: "Executive Office",
                    bio: "31st President, Engineer, Humanitarian, Blamed for Great Depression",
                    expertise: 90,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 30,
                    hawkishness: 35,
                    interventionism: 40,
                    fiscalConservatism: 90,
                    adviceAreas: [.economicAid],
                    currentAdvice: "Prosperity is just around the corner... I hope.",
                    adviceType: .economic,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "stimson_hoover",
                    name: "Henry L. Stimson",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Future War Secretary under FDR, Stimson Doctrine",
                    expertise: 90,
                    loyalty: 85,
                    influence: 80,
                    publicSupport: 70,
                    hawkishness: 60,
                    interventionism: 65,
                    fiscalConservatism: 75,
                    adviceAreas: [.diplomacy],
                    currentAdvice: "We will not recognize territorial changes made by force.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                )
            ]
        )
    }

    // MARK: - Franklin D. Roosevelt Administration (1933-1945)

    static func fdrooseveltAdministration() -> Administration {
        Administration(
            id: "fdr",
            name: "F.D. Roosevelt Administration",
            president: "Franklin D. Roosevelt",
            years: "1933-1945",
            startYear: 1933,
            endYear: 1945,
            party: "Democratic",
            advisors: [
                Advisor(
                    id: "fdr",
                    name: "Franklin D. Roosevelt",
                    title: "President",
                    department: "Executive Office",
                    bio: "32nd President, Led nation through Depression and WW2, Only 4-term president",
                    expertise: 100,
                    loyalty: 100,
                    influence: 100,
                    publicSupport: 85,
                    hawkishness: 70,
                    interventionism: 80,
                    fiscalConservatism: 40,
                    adviceAreas: [.diplomacy, .militaryStrike, .economicAid],
                    currentAdvice: "The only thing we have to fear is fear itself. We will win this war.",
                    adviceType: .military,
                    portraitColor: "#4169E1"
                ),
                Advisor(
                    id: "hull",
                    name: "Cordell Hull",
                    title: "Secretary of State",
                    department: "State",
                    bio: "Longest-serving Secretary, Nobel Peace Prize, Architect of UN",
                    expertise: 95,
                    loyalty: 95,
                    influence: 90,
                    publicSupport: 80,
                    hawkishness: 50,
                    interventionism: 70,
                    fiscalConservatism: 60,
                    adviceAreas: [.diplomacy, .treaties],
                    currentAdvice: "International cooperation will prevent future wars.",
                    adviceType: .diplomatic,
                    portraitColor: "#1E90FF"
                ),
                Advisor(
                    id: "stimson",
                    name: "Henry L. Stimson",
                    title: "Secretary of War",
                    department: "War",
                    bio: "Oversaw Manhattan Project, Advised Truman on atomic bomb",
                    expertise: 95,
                    loyalty: 95,
                    influence: 95,
                    publicSupport: 75,
                    hawkishness: 75,
                    interventionism: 80,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .nuclearWeapons],
                    currentAdvice: "The atomic bomb will end the war and save countless lives.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                ),
                Advisor(
                    id: "marshall_gen",
                    name: "George C. Marshall",
                    title: "Chief of Staff",
                    department: "War",
                    bio: "Five-star General, Organized WW2 victory, Future Secretary of State",
                    expertise: 100,
                    loyalty: 100,
                    influence: 95,
                    publicSupport: 90,
                    hawkishness: 65,
                    interventionism: 75,
                    fiscalConservatism: 70,
                    adviceAreas: [.militaryStrike, .diplomacy],
                    currentAdvice: "Military victory first, then we rebuild Europe with economic aid.",
                    adviceType: .military,
                    portraitColor: "#556B2F"
                )
            ]
        )
    }
}
