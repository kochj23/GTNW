//
//  HistoricalCrises_PreNuclear.swift
//  GTNW
//
//  Historical crises from 1789-1945 (Pre-Nuclear Age)
//  150+ scenarios covering Revolutionary War through World War 2
//  Created by Jordan Koch on 2026-01-26
//

import Foundation

extension HistoricalCrises {

    /// Get crises for pre-nuclear administrations
    static func crisesForPreNuclearAdmin(_ adminID: String) -> [HistoricalCrisis] {
        switch adminID {
        case "washington": return washingtonCrises()
        case "adams": return adamsCrises()
        case "jefferson": return jeffersonCrises()
        case "madison": return madisonCrises()
        case "monroe": return monroeCrises()
        case "jq_adams": return jqAdamsCrises()
        case "jackson": return jacksonCrises()
        case "van_buren": return vanBurenCrises()
        case "harrison": return harrisonCrises()
        case "tyler": return tylerCrises()
        case "polk": return polkCrises()
        case "taylor": return taylorCrises()
        case "fillmore": return fillmoreCrises()
        case "pierce": return pierceCrises()
        case "buchanan": return buchananCrises()
        case "lincoln": return lincolnCrises()
        case "a_johnson": return ajohnsonCrises()
        case "grant": return grantCrises()
        case "hayes": return hayesCrises()
        case "garfield": return garfieldCrises()
        case "arthur": return arthurCrises()
        case "cleveland_first": return clevelandFirstCrises()
        case "harrison_benjamin": return harrisonBenjaminCrises()
        case "cleveland_second": return clevelandSecondCrises()
        case "mckinley": return mckinleyCrises()
        case "t_roosevelt": return trooseveltCrises()
        case "taft": return taftCrises()
        case "wilson": return wilsonCrises()
        case "harding": return hardingCrises()
        case "coolidge": return coolidgeCrises()
        case "hoover": return hooverCrises()
        case "fdr": return fdrCrises()
        default: return []
        }
    }

    // MARK: - Washington Administration (1789-1797) - 8 crises

    static func washingtonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "washington_whiskey_1794",
                title: "Whiskey Rebellion",
                year: 1794,
                description: "Western Pennsylvania farmers violently resist whiskey tax. They tar and feather tax collectors. Some call for independence. This is the first test of federal authority.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Lead militia to suppress rebellion", outcome: "Rebellion crushed. Federal authority established. Some see it as tyranny."),
                    HistoricalCrisisOption(title: "Negotiate with rebels", outcome: "Seen as weakness. Tax collection becomes impossible."),
                    HistoricalCrisisOption(title: "Repeal the tax", outcome: "Federal revenue collapses. Government weakened."),
                    HistoricalCrisisOption(title: "Ignore the rebellion", outcome: "Spreads to other states. Union at risk.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_french_revolution_1793",
                title: "French Revolution - Choose a Side?",
                year: 1793,
                description: "France, our Revolutionary ally, has executed its king and declared war on Britain. France demands we honor our 1778 treaty. Jefferson urges support. Hamilton says stay neutral.",
                countries: ["France", "UK"],
                options: [
                    HistoricalCrisisOption(title: "Declare neutrality", outcome: "France furious. Treaty obligations ignored. But peace maintained."),
                    HistoricalCrisisOption(title: "Support France militarily", outcome: "War with Britain. American economy devastated."),
                    HistoricalCrisisOption(title: "Support Britain secretly", outcome: "France discovers betrayal. Relations ruined."),
                    HistoricalCrisisOption(title: "Mediate between Britain and France", outcome: "Both sides reject interference.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_jays_treaty_1794",
                title: "Jay's Treaty with Britain",
                year: 1794,
                description: "Chief Justice Jay negotiated treaty with Britain. Britain will evacuate forts in Northwest, but treaty says nothing about impressment of American sailors. Public is outraged.",
                countries: ["UK"],
                options: [
                    HistoricalCrisisOption(title: "Ratify the treaty", outcome: "Avoids war with Britain. Jeffersonians call you British puppet. But peace secured."),
                    HistoricalCrisisOption(title: "Reject the treaty", outcome: "Britain maintains forts. War looms. Western expansion halted."),
                    HistoricalCrisisOption(title: "Renegotiate for impressment clause", outcome: "Britain refuses. Negotiations collapse."),
                    HistoricalCrisisOption(title: "Let Senate decide without recommendation", outcome: "Political chaos. Leadership questioned.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_northwest_territory_1790",
                title: "Native American Resistance - Northwest Territory",
                year: 1790,
                description: "Native American confederacy under Little Turtle defeats two US armies. Western settlers demand protection. Expansion threatened.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Send larger army under Anthony Wayne", outcome: "Decisive victory at Fallen Timbers 1794. Northwest opened."),
                    HistoricalCrisisOption(title: "Negotiate territorial compromise", outcome: "Temporary peace. Settlers dissatisfied."),
                    HistoricalCrisisOption(title: "Withdraw and fortify existing borders", outcome: "Seen as defeat. Western expansion stalls."),
                    HistoricalCrisisOption(title: "Militia-only approach (no federal army)", outcome: "Ineffective. Casualties mount.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_farewell_address_1796",
                title: "Farewell Address - Set Foreign Policy",
                year: 1796,
                description: "As you prepare to leave office, you write your farewell address. Your words on foreign policy will guide the nation for generations. What is your core message?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Warn against foreign entanglements", outcome: "Isolationism becomes doctrine for 100+ years. America stays neutral in European wars."),
                    HistoricalCrisisOption(title: "Urge Atlantic alliance with Britain", outcome: "Pro-British policy. Jefferson furious."),
                    HistoricalCrisisOption(title: "Advocate American expansion", outcome: "Manifest Destiny begins early."),
                    HistoricalCrisisOption(title: "Say nothing substantive", outcome: "No guiding principles. Future presidents flounder.")
                ]
            )
        ]
    }

    // MARK: - Adams Administration (1797-1801) - 6 crises

    static func adamsCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "adams_xyz_affair_1797",
                title: "XYZ Affair - France Demands Bribes",
                year: 1797,
                description: "French agents (code-named X, Y, Z) demand $250,000 bribe before negotiations. Public outraged. 'Millions for defense, not one cent for tribute!' Navy building. War fever spreads.",
                countries: ["France"],
                options: [
                    HistoricalCrisisOption(title: "Declare war on France", outcome: "Quasi-War begins. Naval conflict. Expensive but popular."),
                    HistoricalCrisisOption(title: "Pay the bribe secretly", outcome: "If discovered, presidency destroyed."),
                    HistoricalCrisisOption(title: "Build Navy and wait", outcome: "Naval buildup strengthens America. Tensions remain high."),
                    HistoricalCrisisOption(title: "Negotiate despite insult", outcome: "Seen as weak. Federalists revolt.")
                ]
            ),

            HistoricalCrisis(
                id: "adams_alien_sedition_1798",
                title: "Alien and Sedition Acts",
                year: 1798,
                description: "War fever leads Federalists to propose laws criminalizing criticism of government. Jefferson calls them tyranny. Your party demands you sign. Your legacy hangs in balance.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Sign the Acts into law", outcome: "Opposition newspapers shut down. Jefferson elected next president in backlash. Your reputation damaged forever."),
                    HistoricalCrisisOption(title: "Veto the Acts", outcome: "Federalist Party revolts. But Constitution protected."),
                    HistoricalCrisisOption(title: "Sign but not enforce", outcome: "Worst of both worlds. Inconsistency noted."),
                    HistoricalCrisisOption(title: "Advocate repeal after signing", outcome: "Flip-flopping damages credibility.")
                ]
            ),

            HistoricalCrisis(
                id: "adams_peace_1800",
                title: "France Seeks Peace - End Quasi-War?",
                year: 1800,
                description: "Napoleon offers peace treaty. Federalist war hawks want to continue war. Peace will cost you 1800 election. War will cost American lives. Your choice defines your legacy.",
                countries: ["France"],
                options: [
                    HistoricalCrisisOption(title: "Accept peace immediately", outcome: "Quasi-War ends. You lose 1800 election. But peace achieved. History remembers you well."),
                    HistoricalCrisisOption(title: "Continue war for political gain", outcome: "Unnecessary deaths. Moral stain on presidency."),
                    HistoricalCrisisOption(title: "Demand reparations first", outcome: "France refuses. War drags on."),
                    HistoricalCrisisOption(title: "Let next president decide", outcome: "Leadership abdication. Legacy damaged.")
                ]
            )
        ]
    }

    // MARK: - Jefferson Administration (1801-1809) - 10 crises

    static func jeffersonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "jefferson_barbary_pirates_1801",
                title: "Barbary Pirates Demand Tribute",
                year: 1801,
                description: "Barbary States demand $225,000 annual tribute or they will seize American ships and enslave sailors. Previous presidents paid. You campaigned against it.",
                countries: ["Libya"],
                options: [
                    HistoricalCrisisOption(title: "Pay the tribute", outcome: "Hypocrisy noted. But American sailors safe."),
                    HistoricalCrisisOption(title: "Send Navy to fight ('shores of Tripoli')", outcome: "4-year war. Piracy suppressed. America respected."),
                    HistoricalCrisisOption(title: "Avoid Mediterranean trade entirely", outcome: "Commerce damaged. Seen as retreat."),
                    HistoricalCrisisOption(title: "Negotiate better terms", outcome: "Pirates laugh. Tribute increases.")
                ]
            ),

            HistoricalCrisis(
                id: "jefferson_louisiana_1803",
                title: "Louisiana Purchase Opportunity",
                year: 1803,
                description: "Napoleon offers to sell entire Louisiana Territory for $15 million. Doubles US size! But Constitution doesn't authorize such purchases. Strict constructionists (like you) say it's illegal.",
                countries: ["France"],
                options: [
                    HistoricalCrisisOption(title: "Buy it - Constitution be damned", outcome: "America doubles in size. Hypocrisy noted but worth it."),
                    HistoricalCrisisOption(title: "Propose constitutional amendment first", outcome: "Napoleon withdraws offer. Lost forever."),
                    HistoricalCrisisOption(title: "Decline on constitutional grounds", outcome: "Consistency maintained. Opportunity lost. History judges you harshly."),
                    HistoricalCrisisOption(title: "Buy only New Orleans", outcome: "Napoleon refuses partial sale.")
                ]
            ),

            HistoricalCrisis(
                id: "jefferson_chesapeake_1807",
                title: "HMS Leopard Attacks USS Chesapeake",
                year: 1807,
                description: "British warship fires on USS Chesapeake, killing 3, wounding 18, impressing 4 American sailors. Public demands war. You're a pacifist. Britain's Royal Navy vastly superior to American fleet.",
                countries: ["UK"],
                options: [
                    HistoricalCrisisOption(title: "Declare war on Britain", outcome: "Premature war. British burn Washington in 1814."),
                    HistoricalCrisisOption(title: "Embargo Act - ban all foreign trade", outcome: "American economy devastated. Embargo fails. Unpopular."),
                    HistoricalCrisisOption(title: "Demand apology and reparations", outcome: "Britain refuses. Humiliation continues."),
                    HistoricalCrisisOption(title: "Build Navy for future confrontation", outcome: "Wise but slow. Impressment continues.")
                ]
            ),

            HistoricalCrisis(
                id: "jefferson_burr_conspiracy_1806",
                title: "Burr Conspiracy - Treason by Former VP",
                year: 1806,
                description: "Your former Vice President Aaron Burr is raising army in the West. Reports say he plans to conquer Mexico, or split off Western states, or both. Treason trial will be controversial.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Arrest Burr for treason", outcome: "Trial fails (lack of evidence). Burr goes free. Constitutional crisis."),
                    HistoricalCrisisOption(title: "Military force to disperse his army", outcome: "Burr flees. Never tried. Mystery remains."),
                    HistoricalCrisisOption(title: "Ignore the rumors", outcome: "Burr's plot proceeds. Western states in danger."),
                    HistoricalCrisisOption(title: "Offer Burr pardon to stand down", outcome: "Negotiating with traitors sets bad precedent.")
                ]
            )
        ]
    }

    // MARK: - Madison Administration (1809-1817) - 12 crises

    static func madisonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "madison_war_1812_declaration",
                title: "Declare War on Britain? (War of 1812)",
                year: 1812,
                description: "British impress 6,000 American sailors, arm Native Americans against us, blockade our trade. War Hawks demand war. Federalists warn of British military might. Your decision.",
                countries: ["UK"],
                options: [
                    HistoricalCrisisOption(title: "Declare war", outcome: "War of 1812 begins. British burn Washington. But America proves its independence."),
                    HistoricalCrisisOption(title: "Continue negotiations", outcome: "Britain ignores you. Impressment continues. National humiliation."),
                    HistoricalCrisisOption(title: "Economic embargo only", outcome: "Hurts American economy more than Britain. Fails."),
                    HistoricalCrisisOption(title: "War only if Britain attacks first", outcome: "Decades of tension. No resolution.")
                ]
            ),

            HistoricalCrisis(
                id: "madison_washington_burned_1814",
                title: "British Burn Washington D.C.",
                year: 1814,
                description: "British army marches on capital. Militia flees. White House, Capitol, and government buildings will be torched. You must flee. Darkest moment of the war. Continue fighting or sue for peace?",
                countries: ["UK"],
                options: [
                    HistoricalCrisisOption(title: "Continue war despite capital loss", outcome: "Jackson wins at New Orleans. National morale restored. Treaty of Ghent ends war."),
                    HistoricalCrisisOption(title: "Immediate peace negotiations", outcome: "Negotiating from weakness. British demands increase."),
                    HistoricalCrisisOption(title: "Resign presidency", outcome: "National disaster. Britain wins."),
                    HistoricalCrisisOption(title: "Relocate capital permanently", outcome: "Seen as running away. Political chaos.")
                ]
            ),

            HistoricalCrisis(
                id: "madison_hartford_convention_1814",
                title: "Hartford Convention - New England Secession?",
                year: 1814,
                description: "New England Federalists meet secretly in Hartford. Rumors of secession and separate peace with Britain. Constitution in danger. Your response?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Threaten military force", outcome: "Civil war risk. But Convention backs down."),
                    HistoricalCrisisOption(title: "Ignore them", outcome: "Jackson's victory at New Orleans makes them look foolish. Federalist Party destroyed."),
                    HistoricalCrisisOption(title: "Negotiate grievances", outcome: "Legitimizes secession talk."),
                    HistoricalCrisisOption(title: "Arrest Convention leaders", outcome: "Martyrdom. Northeast in revolt.")
                ]
            ),

            HistoricalCrisis(
                id: "madison_jackson_new_orleans_1815",
                title: "Battle of New Orleans - After Peace Signed?",
                year: 1815,
                description: "Andrew Jackson wins glorious victory at New Orleans, killing 2,000 British with only 71 American losses. Problem: Peace treaty was signed 2 weeks earlier. News just hadn't arrived. Celebrate or condemn?",
                countries: ["UK"],
                options: [
                    HistoricalCrisisOption(title: "Celebrate Jackson as hero", outcome: "National pride restored. War ends on high note. Jackson becomes president later."),
                    HistoricalCrisisOption(title: "Condemn unnecessary bloodshed", outcome: "Public revolts. Jackson your enemy forever."),
                    HistoricalCrisisOption(title: "Quietly acknowledge", outcome: "Muted response. Moment wasted."),
                    HistoricalCrisisOption(title: "Demand Britain pay reparations", outcome: "Britain refuses. Peace treaty endangered.")
                ]
            )
        ]
    }

    // MARK: - Monroe Administration (1817-1825) - 8 crises

    static func monroeCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "monroe_doctrine_1823",
                title: "Monroe Doctrine - Defy Europe",
                year: 1823,
                description: "Spain's American colonies are winning independence. European powers consider intervention to restore monarchies. John Quincy Adams urges bold declaration: European colonization of Americas is over. But we lack military to enforce it.",
                countries: ["Spain", "France", "Russia"],
                options: [
                    HistoricalCrisisOption(title: "Issue Monroe Doctrine", outcome: "European powers warned off. Doctrine defines American policy for 100+ years. But it's a bluff."),
                    HistoricalCrisisOption(title: "Ally with Britain to enforce", outcome: "Britain gets credit. America looks weak."),
                    HistoricalCrisisOption(title: "Say nothing", outcome: "Europeans re-colonize Latin America. Hemisphere dominated."),
                    HistoricalCrisisOption(title: "Offer to mediate conflicts", outcome: "All sides ignore you.")
                ]
            ),

            HistoricalCrisis(
                id: "monroe_florida_1818",
                title: "Jackson Invades Spanish Florida",
                year: 1818,
                description: "General Andrew Jackson, pursuing Seminole raiders, invades Spanish Florida without authorization, executes two British citizens, and seizes Spanish forts. Spain demands punishment. Jackson has public support.",
                countries: ["Spain", "UK"],
                options: [
                    HistoricalCrisisOption(title: "Defend Jackson's actions", outcome: "Spain forced to sell Florida. Britain protests. Jackson grateful."),
                    HistoricalCrisisOption(title: "Apologize and censure Jackson", outcome: "Spain mollified. Jackson becomes your enemy. Western voters angry."),
                    HistoricalCrisisOption(title: "Claim Jackson misunderstood orders", outcome: "Transparent lie. Credibility damaged."),
                    HistoricalCrisisOption(title: "Offer Spain compensation", outcome: "Treasury drained. Seen as weak.")
                ]
            ),

            HistoricalCrisis(
                id: "monroe_missouri_compromise_1820",
                title: "Missouri Crisis - Slavery Expansion",
                year: 1820,
                description: "Missouri seeks statehood as slave state. Would upset free/slave balance. 'This momentous question, like a fire bell in the night, awakened and filled me with terror' - Jefferson. Nation splitting.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Support Missouri Compromise (ban slavery north of 36°30')", outcome: "Crisis delayed 40 years. But problem not solved."),
                    HistoricalCrisisOption(title: "Ban slavery in Missouri", outcome: "South threatens secession. Union in danger."),
                    HistoricalCrisisOption(title: "Allow slavery to expand freely", outcome: "North furious. Abolition movement accelerates."),
                    HistoricalCrisisOption(title: "Let Congress decide without input", outcome: "Gridlock. No state admitted.")
                ]
            )
        ]
    }

    // MARK: - Jackson Administration (1829-1837) - 15 crises

    static func jacksonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "jackson_indian_removal_1830",
                title: "Indian Removal Act",
                year: 1830,
                description: "Congress authorizes forced relocation of 60,000 Native Americans from Southeast to Oklahoma. Cherokee have adopted white culture, have written language, own newspaper. Supreme Court sides with them. You must choose.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Enforce removal (Trail of Tears)", outcome: "4,000 Cherokee die. Ethnic cleansing stain on presidency. But land opened for settlers."),
                    HistoricalCrisisOption(title: "Respect Supreme Court ruling", outcome: "Cherokee remain. Southern states furious. Secession talk begins."),
                    HistoricalCrisisOption(title: "Voluntary relocation with compensation", outcome: "Few accept. Problem lingers."),
                    HistoricalCrisisOption(title: "Create Native American state in Oklahoma", outcome: "Radical idea. No support.")
                ]
            ),

            HistoricalCrisis(
                id: "jackson_nullification_1832",
                title: "Nullification Crisis - South Carolina",
                year: 1832,
                description: "South Carolina declares federal tariff null and void, threatens secession. Vice President Calhoun supports them. 'The Union must be preserved' vs states' rights. Your move.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Threaten military force", outcome: "'I will hang Calhoun!' South Carolina backs down. Civil war postponed 30 years."),
                    HistoricalCrisisOption(title: "Accept nullification doctrine", outcome: "Federal authority destroyed. States ignore laws at will. Nation collapses."),
                    HistoricalCrisisOption(title: "Lower tariff to appease South", outcome: "Compromise works. Crisis defused. Precedent set."),
                    HistoricalCrisisOption(title: "Call constitutional convention", outcome: "Opens pandora's box. Chaos.")
                ]
            ),

            HistoricalCrisis(
                id: "jackson_bank_war_1832",
                title: "Bank War - Veto Recharter?",
                year: 1832,
                description: "Second Bank of the United States seeks recharter. You hate banks. But Nicholas Biddle warns removing federal bank will cause economic chaos. Clay makes it election issue.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Veto bank recharter", outcome: "Popular but causes Panic of 1837 after you leave office."),
                    HistoricalCrisisOption(title: "Sign recharter reluctantly", outcome: "Political base revolts. Seen as sellout."),
                    HistoricalCrisisOption(title: "Reform and recharter", outcome: "Compromise. Nobody happy."),
                    HistoricalCrisisOption(title: "Let bank die without comment", outcome: "Financial chaos. No plan to replace it.")
                ]
            ),

            HistoricalCrisis(
                id: "jackson_texas_independence_1836",
                title: "Texas Independence - Recognize?",
                year: 1836,
                description: "Texas declares independence from Mexico after Battle of San Jacinto. Texans want annexation to US. But this means war with Mexico and inflames slavery debate. Sam Houston waiting.",
                countries: ["Mexico"],
                options: [
                    HistoricalCrisisOption(title: "Recognize Texas immediately", outcome: "Mexico breaks relations. War looms."),
                    HistoricalCrisisOption(title: "Annex Texas immediately", outcome: "Mexican-American War begins in 1836 instead of 1846."),
                    HistoricalCrisisOption(title: "Delay recognition", outcome: "Texas remains independent. Mexico threatens reconquest."),
                    HistoricalCrisisOption(title: "Support Mexican government", outcome: "Texas feels betrayed. Might ally with Britain.")
                ]
            )
        ]
    }

    // MARK: - Polk Administration (1845-1849) - 12 crises

    static func polkCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "polk_54_40_1845",
                title: "Oregon Territory - '54-40 or Fight!'",
                year: 1845,
                description: "Oregon Territory jointly occupied by US and Britain. Expansionists demand all territory to 54°40' (southern Alaska). Britain offers to split at 49th parallel. War or compromise?",
                countries: ["UK"],
                options: [
                    HistoricalCrisisOption(title: "Demand 54-40 or fight", outcome: "Britain prepares for war. But you're about to fight Mexico too. Two-front war disaster."),
                    HistoricalCrisisOption(title: "Accept 49th parallel compromise", outcome: "Peacefully acquire vast territory. Focus on Mexico instead."),
                    HistoricalCrisisOption(title: "Propose arbitration", outcome: "Britain refuses. Deadlock continues."),
                    HistoricalCrisisOption(title: "Withdraw US claims", outcome: "Political suicide. Pacific Northwest lost.")
                ]
            ),

            HistoricalCrisis(
                id: "polk_mexican_war_1846",
                title: "Mexican-American War - Provoke or Wait?",
                year: 1846,
                description: "Texas annexation leads to border dispute. Mexico claims Nueces River. US claims Rio Grande. You want California. Send army to disputed zone to provoke war?",
                countries: ["Mexico"],
                options: [
                    HistoricalCrisisOption(title: "Order Taylor into disputed zone", outcome: "Mexican attack. 'American blood on American soil!' War declared. You acquire California and Southwest."),
                    HistoricalCrisisOption(title: "Negotiate border", outcome: "Mexico refuses. Stalemate. California remains Mexican."),
                    HistoricalCrisisOption(title: "Wait for Mexican attack", outcome: "Mexico doesn't attack. No war justification."),
                    HistoricalCrisisOption(title: "Offer to buy California", outcome: "Mexico refuses to sell. National pride at stake.")
                ]
            ),

            HistoricalCrisis(
                id: "polk_veracruz_1847",
                title: "Veracruz Landing - End War How?",
                year: 1847,
                description: "Winfield Scott captured Mexico City. Total victory. But Mexico won't negotiate. Advisors split: Annex all of Mexico vs take California/Southwest vs withdraw and declare victory.",
                countries: ["Mexico"],
                options: [
                    HistoricalCrisisOption(title: "Annex all of Mexico", outcome: "Slavery debate explodes. Mexican resistance continues. Impossible to govern."),
                    HistoricalCrisisOption(title: "Take California and Southwest only", outcome: "Treaty of Guadalupe Hidalgo. Mexican Cession. Manifest Destiny achieved."),
                    HistoricalCrisisOption(title: "Withdraw and declare victory", outcome: "Nothing gained. War seen as pointless. Political disaster."),
                    HistoricalCrisisOption(title: "Install puppet regime in Mexico", outcome: "Mexican nationalism. Endless guerrilla war.")
                ]
            )
        ]
    }

    // MARK: - Lincoln Administration (1861-1865) - 25 crises

    static func lincolnCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "lincoln_fort_sumter_1861",
                title: "Fort Sumter - Let South Fire First?",
                year: 1861,
                description: "Confederate forces surround Fort Sumter in Charleston harbor. Resupply convoy ready. If you send it, they'll fire. Civil War begins. But who fires first matters morally and politically.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Send resupply convoy", outcome: "Confederates fire first. You have moral high ground. North unites. 4-year war begins."),
                    HistoricalCrisisOption(title: "Evacuate Fort Sumter", outcome: "Seen as accepting secession. Border states join Confederacy. War still comes but from weaker position."),
                    HistoricalCrisisOption(title: "Blockade Charleston", outcome: "Slow strangulation. War starts anyway but goal unclear."),
                    HistoricalCrisisOption(title: "Negotiate Confederate independence", outcome: "Union dissolved. Slavery perpetuated. Lincoln legacy destroyed.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_emancipation_1862",
                title: "Emancipation Proclamation Timing",
                year: 1862,
                description: "You've written Emancipation Proclamation freeing slaves in rebel states. Cabinet says wait for military victory or it looks desperate. Abolitionists demand immediate action. Border states threaten to leave.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Issue after Antietam victory", outcome: "Moral cause proclaimed. Europe won't recognize Confederacy. Border states angry but stay."),
                    HistoricalCrisisOption(title: "Issue immediately", outcome: "Looks desperate. Border states secede. War becomes unwinnable."),
                    HistoricalCrisisOption(title: "Wait for complete victory", outcome: "Too late. Moral opportunity lost."),
                    HistoricalCrisisOption(title: "Free slaves gradually over 10 years", outcome: "Abolitionists furious. Half-measure satisfies nobody.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_trent_affair_1861",
                title: "Trent Affair - War with Britain During Civil War?",
                year: 1861,
                description: "US Navy stops British ship HMS Trent, arrests Confederate diplomats. Britain demands release and apology. Public wants to keep them. But war with Britain during Civil War means certain defeat.",
                countries: ["UK"],
                options: [
                    HistoricalCrisisOption(title: "Release diplomats and apologize", outcome: "Humiliating but avoids two-front war. Britain stays neutral."),
                    HistoricalCrisisOption(title: "Keep diplomats, defy Britain", outcome: "Britain joins Confederacy. Union crushed."),
                    HistoricalCrisisOption(title: "Offer compromise (release without apology)", outcome: "Britain demands full apology. Doesn't work."),
                    HistoricalCrisisOption(title: "Propose international arbitration", outcome: "Too slow. Britain invades Canada. War begins.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_habeas_corpus_1861",
                title: "Suspend Habeas Corpus?",
                year: 1861,
                description: "Maryland Confederate sympathizers sabotage railroads. Chief Justice Taney rules you can't suspend habeas corpus. But national security requires jailing suspects without trial. Constitution vs survival.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Suspend habeas corpus anyway", outcome: "Thousands jailed without trial. Civil liberties damaged. But Union secured."),
                    HistoricalCrisisOption(title: "Obey Supreme Court", outcome: "Sabotage continues. War effort hindered."),
                    HistoricalCrisisOption(title: "Selective enforcement", outcome: "Inconsistent. Rule of law questioned."),
                    HistoricalCrisisOption(title: "Seek Congressional authorization", outcome: "Congress debates. Maryland secedes while you wait.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_gettysburg_1863",
                title: "After Gettysburg - Peace Overture from South?",
                year: 1863,
                description: "Lee defeated at Gettysburg. 50,000 casualties in 3 days. Confederate VP Stephens offers peace talks: Independence for Confederacy, slavery remains, peaceful coexistence. War is winnable but costly. Peace now or fight to total victory?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Accept peace talks", outcome: "Union dissolved. Two American nations. Slavery perpetuated indefinitely."),
                    HistoricalCrisisOption(title: "Demand unconditional surrender only", outcome: "War continues 2 more years. 400,000 more dead. But Union restored and slavery ended."),
                    HistoricalCrisisOption(title: "Negotiate reunion with slavery protected", outcome: "Union nominally restored. But moral stain remains. Future civil war inevitable."),
                    HistoricalCrisisOption(title: "Offer gradual compensated emancipation", outcome: "South rejects. North says too weak.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_booth_1865",
                title: "Assassination Threat Detected",
                year: 1865,
                description: "Intelligence reports plot to assassinate you at Ford's Theatre. Ward Hill Lamon, your bodyguard, begs you not to go. But the war is won. What threat could remain?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Go to theater anyway (history)", outcome: "John Wilkes Booth shoots you. You die. Johnson becomes president. Reconstruction disaster."),
                    HistoricalCrisisOption(title: "Stay home tonight", outcome: "Booth finds another time. Assassination delayed or prevented?"),
                    HistoricalCrisisOption(title: "Bring extra security", outcome: "Booth scared off. You survive. Reconstruction succeeds under your leadership."),
                    HistoricalCrisisOption(title: "Arrest suspicious actors preemptively", outcome: "Booth caught. Conspiracy unraveled. But false arrests too.")
                ]
            )
        ]
    }

    // MARK: - T. Roosevelt Administration (1901-1909) - 18 crises

    static func trooseveltCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "troosevelt_panama_canal_1903",
                title: "Panama Canal - Start a Revolution?",
                year: 1903,
                description: "You want canal across Panama but Colombia rejects treaty. Panamanians want independence. Philippe Bunau-Varilla offers to organize revolution if US Navy supports it. Create a country to build a canal?",
                countries: ["Colombia", "Panama"],
                options: [
                    HistoricalCrisisOption(title: "Support Panama revolution", outcome: "Panama independent in 3 days. US gets canal zone. But you created a nation for commercial gain."),
                    HistoricalCrisisOption(title: "Negotiate better terms with Colombia", outcome: "Years of talks. No canal. Germany might build it instead."),
                    HistoricalCrisisOption(title: "Build canal through Nicaragua", outcome: "More expensive. Takes longer. Panama stays with Colombia."),
                    HistoricalCrisisOption(title: "Abandon canal project", outcome: "Strategic opportunity lost. Pacific access delayed decades.")
                ]
            ),

            HistoricalCrisis(
                id: "troosevelt_great_white_fleet_1907",
                title: "Great White Fleet - Provoke Japan?",
                year: 1907,
                description: "Japan's navy growing powerful after defeating Russia. Admiral Mahan suggests circumnavigating globe with entire battle fleet to show American power. Japan may see it as threat. Send the fleet?",
                countries: ["Japan"],
                options: [
                    HistoricalCrisisOption(title: "Send Great White Fleet", outcome: "Massive show of force. Japan impressed. But relations strained."),
                    HistoricalCrisisOption(title: "Cancel to avoid provoking Japan", outcome: "Seen as weak. Japan emboldens. Expansion continues."),
                    HistoricalCrisisOption(title: "Send only to Pacific, not Japan", outcome: "Compromise. Message unclear."),
                    HistoricalCrisisOption(title: "Invite Japan to naval exercises", outcome: "Japan declines. Goodwill gesture ignored.")
                ]
            ),

            HistoricalCrisis(
                id: "troosevelt_coal_strike_1902",
                title: "Coal Strike - Side with Labor or Capital?",
                year: 1902,
                description: "140,000 coal miners strike. Winter coming. Nation faces heating crisis. Mine owners refuse arbitration. You have no constitutional authority to intervene in private dispute. But people will freeze.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Threaten to seize mines with Army", outcome: "Owners cave. Strike settled. But you exceeded authority. Precedent set for federal intervention."),
                    HistoricalCrisisOption(title: "Side with owners", outcome: "Strike crushed. But labor radicalized. Socialist movement grows."),
                    HistoricalCrisisOption(title: "Force arbitration", outcome: "Compromise. Miners get 10% raise. Your Square Deal begins."),
                    HistoricalCrisisOption(title: "Let crisis resolve itself", outcome: "People freeze. Riots. Political disaster.")
                ]
            ),

            HistoricalCrisis(
                id: "troosevelt_russo_japanese_1905",
                title: "Russo-Japanese War - Mediate for Nobel Prize?",
                year: 1905,
                description: "Russia and Japan locked in bloody war. Both exhausted. You can mediate peace, earn Nobel Prize, establish America as world power. But picking sides risks alienating the loser.",
                countries: ["Russia", "Japan"],
                options: [
                    HistoricalCrisisOption(title: "Mediate Treaty of Portsmouth", outcome: "Peace achieved. You win Nobel Prize. America now Pacific power. But Russia embittered."),
                    HistoricalCrisisOption(title: "Side openly with Japan", outcome: "Japan victorious. Russia hostile forever."),
                    HistoricalCrisisOption(title: "Side with Russia", outcome: "White race solidarity. But Japan becomes enemy."),
                    HistoricalCrisisOption(title: "Stay out entirely", outcome: "Europe mediates. America irrelevant in Pacific.")
                ]
            )
        ]
    }

    // MARK: - Wilson Administration (1913-1921) - 20 crises

    static func wilsonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "wilson_lusitania_1915",
                title: "Lusitania Sunk by German U-Boat",
                year: 1915,
                description: "German submarine sinks British liner Lusitania. 1,198 dead including 128 Americans. Public demands war. But you promised neutrality. Germany says ship carried munitions (it did). Your move.",
                countries: ["Germany", "UK"],
                options: [
                    HistoricalCrisisOption(title: "Declare war on Germany", outcome: "Premature. America unprepared. Public support weak."),
                    HistoricalCrisisOption(title: "Stern warning to Germany", outcome: "Germany apologizes, restricts submarine warfare temporarily. War delayed 2 years."),
                    HistoricalCrisisOption(title: "Accept German apology", outcome: "Seen as weak. More American ships sunk."),
                    HistoricalCrisisOption(title: "Ban Americans from traveling on belligerent ships", outcome: "Unpopular. Retreating from freedom of seas.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_zimmermann_1917",
                title: "Zimmermann Telegram Intercepted",
                year: 1917,
                description: "British intelligence intercepts German telegram proposing Mexico ally with Germany, attack US, reconquer Texas/Arizona/New Mexico. Germany to resume unrestricted submarine warfare. This is your war declaration justification.",
                countries: ["Germany", "Mexico"],
                options: [
                    HistoricalCrisisOption(title: "Declare war on Germany", outcome: "America enters WW1. 116,000 Americans die. But victory in 1918. Germany defeated."),
                    HistoricalCrisisOption(title: "Continue armed neutrality", outcome: "More American ships sunk. Pressure mounts. War inevitable anyway."),
                    HistoricalCrisisOption(title: "Invade Mexico preemptively", outcome: "Wrong enemy. Germany wins in Europe."),
                    HistoricalCrisisOption(title: "Offer to mediate peace in Europe", outcome: "All sides reject. America sidelined.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_versailles_1919",
                title: "Treaty of Versailles - Punish Germany?",
                year: 1919,
                description: "Germany defeated. France demands crushing reparations. You want lenient peace and League of Nations. Clemenceau and Lloyd George want vengeance. Harsh peace breeds future war. Compromise?",
                countries: ["Germany", "France", "UK"],
                options: [
                    HistoricalCrisisOption(title: "Support harsh reparations", outcome: "Germany economically destroyed. Hitler rises in 20 years. WW2 ensues."),
                    HistoricalCrisisOption(title: "Fight for lenient peace", outcome: "France refuses. You fail. Treaty is harsh anyway. But you tried."),
                    HistoricalCrisisOption(title: "Walk out of negotiations", outcome: "Europe makes own peace. League of Nations without America."),
                    HistoricalCrisisOption(title: "Propose Marshall Plan-style rebuilding", outcome: "Too radical for 1919. Rejected. But prescient.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_league_of_nations_1919",
                title: "League of Nations - Senate Rejects Treaty",
                year: 1919,
                description: "Your League of Nations treaty fails in Senate. Republicans demand reservations protecting American sovereignty. Accept reservations or watch dream die?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Accept Lodge reservations", outcome: "League created with America. Might prevent WW2."),
                    HistoricalCrisisOption(title: "Refuse any changes to treaty", outcome: "Treaty fails. America never joins League. Your dream dies. League fails without America."),
                    HistoricalCrisisOption(title: "Campaign to pressure Senate", outcome: "You suffer stroke. Presidency collapses. Treaty still fails."),
                    HistoricalCrisisOption(title: "Compromise with moderate reservations", outcome: "Narrow path. Possible success.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_red_scare_1919",
                title: "Red Scare - Palmer Raids",
                year: 1919,
                description: "Communist revolution spreads from Russia. Anarchist bombings in US. Attorney General Palmer wants to arrest 10,000 suspected radicals without warrants. Deportations. Civil liberties in danger.",
                countries: ["USA", "USSR"],
                options: [
                    HistoricalCrisisOption(title: "Authorize Palmer Raids", outcome: "6,000 arrested. Mostly innocent. Civil liberties trampled. Red Scare hysteria."),
                    HistoricalCrisisOption(title: "Refuse to authorize", outcome: "More bombings. Palmer runs against you. But Constitution protected."),
                    HistoricalCrisisOption(title: "Targeted operations only", outcome: "Some radicals caught. Civil liberties mostly preserved."),
                    HistoricalCrisisOption(title: "Pardon all arrested radicals", outcome: "Political suicide. Seen as soft on communism.")
                ]
            )
        ]
    }

    // MARK: - Hoover Administration (1929-1933) - 10 crises

    static func hooverCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "hoover_crash_1929",
                title: "Stock Market Crash - Black Tuesday",
                year: 1929,
                description: "Stock market loses 50% in days. Banks failing. Unemployment soaring. People demand federal action. But you believe in limited government. Intervention or let market correct?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Federal intervention programs", outcome: "Contradicts principles but helps economy. Critics say too little too late."),
                    HistoricalCrisisOption(title: "Let market self-correct", outcome: "Depression deepens. 25% unemployment. Hoovervilles. Political disaster."),
                    HistoricalCrisisOption(title: "Encourage private charity", outcome: "Inadequate. Suffering continues."),
                    HistoricalCrisisOption(title: "Public works programs", outcome: "Helps but not enough. FDR will do it bigger.")
                ]
            ),

            HistoricalCrisis(
                id: "hoover_bonus_army_1932",
                title: "Bonus Army - Attack Veterans?",
                year: 1932,
                description: "15,000 WW1 veterans camp in Washington demanding early bonus payment. Congress refuses. Veterans won't leave. MacArthur wants to clear them with Army. Attack veterans during election year?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Order MacArthur to disperse camps", outcome: "Tanks and tear gas against veterans. Photos shock nation. Lose 1932 election in landslide."),
                    HistoricalCrisisOption(title: "Pay the bonus early", outcome: "Treasury drained. Deficit explodes. But veterans go home peacefully."),
                    HistoricalCrisisOption(title: "Negotiate departure", outcome: "Most leave. Remaining campers stay indefinitely."),
                    HistoricalCrisisOption(title: "Ignore them", outcome: "Camps grow. Embarrassment continues. Still lose election.")
                ]
            ),

            HistoricalCrisis(
                id: "hoover_japan_manchuria_1931",
                title: "Japan Invades Manchuria - Respond?",
                year: 1931,
                description: "Japan invades Chinese Manchuria in violation of treaties. League of Nations asks US position. Secretary Stimson wants non-recognition doctrine. Isolationists say stay out. This sets precedent for future aggressors.",
                countries: ["Japan", "China"],
                options: [
                    HistoricalCrisisOption(title: "Issue Stimson Doctrine (non-recognition)", outcome: "Moral stand taken. But no teeth. Japan ignores it. Precedent set that aggression has no consequences."),
                    HistoricalCrisisOption(title: "Economic sanctions on Japan", outcome: "Japan begins seeing US as enemy. Path to Pearl Harbor begins."),
                    HistoricalCrisisOption(title: "Recognize Japanese conquest", outcome: "Morally bankrupt. Aggression rewarded."),
                    HistoricalCrisisOption(title: "Stay silent", outcome: "Appeasement. Emboldens future aggressors.")
                ]
            )
        ]
    }

    // MARK: - FDR Administration (1933-1945) - 30 crises

    static func fdrCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "fdr_bank_holiday_1933",
                title: "Banking Crisis - Close All Banks?",
                year: 1933,
                description: "Banking system collapsing. $140 billion in deposits at risk. Runs on banks. You have radical idea: Close EVERY bank for 4 days, inspect them, reopen only sound ones. Unprecedented federal power.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Declare Bank Holiday", outcome: "Panic stops. Banking system stabilized. 'The only thing we have to fear is fear itself.' Presidency made."),
                    HistoricalCrisisOption(title: "Let states handle it", outcome: "Uncoordinated response. Banking collapse continues."),
                    HistoricalCrisisOption(title: "Federal guarantee of all deposits", outcome: "Moral hazard. Costs explode."),
                    HistoricalCrisisOption(title: "Do nothing", outcome: "Total economic collapse. Revolution possible.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_court_packing_1937",
                title: "Supreme Court Packing Plan",
                year: 1937,
                description: "Supreme Court strikes down New Deal programs. You propose adding 6 justices (one for each justice over 70). Gives you 15-person court with majority. Expands power but threatens checks and balances.",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Push court-packing plan", outcome: "Plan fails. But Court gets message, stops blocking New Deal. Tactical victory."),
                    HistoricalCrisisOption(title: "Abandon plan", outcome: "Court continues blocking programs. New Deal limited."),
                    HistoricalCrisisOption(title: "Wait for justices to retire naturally", outcome: "Years pass. Programs struck down."),
                    HistoricalCrisisOption(title: "Constitutional amendment to clarify power", outcome: "Takes years. States reject.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_lend_lease_1941",
                title: "Lend-Lease - Arm Britain Without War?",
                year: 1941,
                description: "Britain broke, alone against Hitler. Churchill begs for aid. Neutrality Acts forbid it. You propose 'lending' weapons we know won't be returned. Technically neutral but really joining war. Isolationists furious.",
                countries: ["UK", "Germany"],
                options: [
                    HistoricalCrisisOption(title: "Push Lend-Lease through Congress", outcome: "Britain survives. Arsenal of Democracy. Hitler declares war eventually anyway."),
                    HistoricalCrisisOption(title: "Maintain strict neutrality", outcome: "Britain falls. Hitler controls Europe. America alone vs Nazis."),
                    HistoricalCrisisOption(title: "Sell weapons for cash only", outcome: "Britain can't pay. Falls to Hitler."),
                    HistoricalCrisisOption(title: "Declare war immediately", outcome: "Public not ready. Political disaster. Lose Congress.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_pearl_harbor_1941",
                title: "Pearl Harbor - Day of Infamy Response",
                year: 1941,
                description: "Japan attacks Pearl Harbor. 2,403 Americans dead. Pacific Fleet crippled. Congress will declare war. But do you also declare war on Germany (Hitler's ally) or just Japan?",
                countries: ["Japan", "Germany", "Italy"],
                options: [
                    HistoricalCrisisOption(title: "War on Japan only", outcome: "Hitler declares war on YOU 3 days later. Two-front war begins."),
                    HistoricalCrisisOption(title: "War on all Axis powers", outcome: "Two-front war by your choice. Hitler might have stayed out otherwise."),
                    HistoricalCrisisOption(title: "Negotiate with Japan", outcome: "After Pearl Harbor? Political impossibility. Japan would refuse."),
                    HistoricalCrisisOption(title: "Focus on Germany first, hold Japan", outcome: "Europe First strategy. Correct choice.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_internment_1942",
                title: "Japanese-American Internment",
                year: 1942,
                description: "Military urges internment of 120,000 Japanese-Americans from West Coast. Claim espionage risk. No evidence of disloyalty. But post-Pearl Harbor fear is real. Greatest civil rights decision of war.",
                countries: ["USA", "Japan"],
                options: [
                    HistoricalCrisisOption(title: "Sign Executive Order 9066 (internment)", outcome: "120,000 citizens imprisoned. Constitutional stain. But politically popular."),
                    HistoricalCrisisOption(title: "Refuse internment", outcome: "Military and public furious. Political risk. But Constitution protected."),
                    HistoricalCrisisOption(title: "Voluntary relocation with compensation", outcome: "Few accept. Problem persists."),
                    HistoricalCrisisOption(title: "Intern only provable security risks", outcome: "Fair but time-consuming. Public says not enough.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_stalin_1943",
                title: "Stalin Demands Second Front",
                year: 1943,
                description: "USSR suffering 90% of Allied casualties vs Germany. Stalin demands second front in France NOW. But Eisenhower says premature. Stalin hints at separate peace with Hitler if abandoned.",
                countries: ["USSR", "Germany"],
                options: [
                    HistoricalCrisisOption(title: "Invade France in 1943", outcome: "Premature. Heavy casualties. Might fail. But Stalin appeased."),
                    HistoricalCrisisOption(title: "Delay until 1944 (D-Day)", outcome: "Stalin furious but USSR holds. Invasion succeeds. More dead Soviets."),
                    HistoricalCrisisOption(title: "Invade through Balkans instead", outcome: "Churchill's plan. Germany not defeated. Stalin hostile."),
                    HistoricalCrisisOption(title: "Focus on Pacific, let USSR handle Germany", outcome: "Stalin makes separate peace. Hitler controls Europe.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_yalta_1945",
                title: "Yalta Conference - Divide Post-War World",
                year: 1945,
                description: "You, Churchill, Stalin meet to plan post-war order. Stalin wants Eastern Europe. Churchill wants free elections. You want Soviet entry into Pacific War. Everyone wants something. Your health failing.",
                countries: ["USSR", "UK"],
                options: [
                    HistoricalCrisisOption(title: "Grant Stalin Eastern Europe for Pacific help", outcome: "Cold War begins. Eastern Europe enslaved 50 years. But Japan defeated faster."),
                    HistoricalCrisisOption(title: "Demand free elections everywhere", outcome: "Stalin refuses. Soviet-American relations sour immediately."),
                    HistoricalCrisisOption(title: "Partition Germany permanently", outcome: "Germany divided. Cold War flashpoint."),
                    HistoricalCrisisOption(title: "Threaten Stalin with atomic bomb", outcome: "Stalin doesn't believe it exists. Backfires.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_atomic_bomb_1945",
                title: "Manhattan Project Briefing - Continue?",
                year: 1945,
                description: "Secret project to build atomic bomb approaching success. $2 billion spent. 130,000 people working. Germany almost defeated (original target). Japan remains. Scientists warn of nuclear arms race. Continue?",
                countries: ["Japan", "Germany"],
                options: [
                    HistoricalCrisisOption(title: "Complete atomic bomb", outcome: "Bomb ready August 1945. Truman decides to use it."),
                    HistoricalCrisisOption(title: "Cancel project, destroy research", outcome: "Nuclear age delayed. War with Japan continues conventionally. Scientists flee to USSR."),
                    HistoricalCrisisOption(title: "Share research with USSR", outcome: "Atomic monopoly surrendered. But Cold War prevented?"),
                    HistoricalCrisisOption(title: "Use on Germany as originally planned", outcome: "Too late. Germany surrenders May 1945.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_death_1945",
                title: "Your Health Failing - Hand Over to Truman?",
                year: 1945,
                description: "You're dying. Cerebral hemorrhage imminent. Truman knows nothing about atomic bomb, nothing about Stalin, nothing about post-war plans. Brief him now or keep secrets?",
                countries: ["USA"],
                options: [
                    HistoricalCrisisOption(title: "Brief Truman on everything", outcome: "Truman prepared. Smooth transition. Wise choice."),
                    HistoricalCrisisOption(title: "Keep secrets until necessary", outcome: "Historical choice. Truman shocked by atomic bomb revelation. Struggles initially."),
                    HistoricalCrisisOption(title: "Resign to let Truman prepare", outcome: "Unprecedented. Presidency weakened."),
                    HistoricalCrisisOption(title: "Request 5th term to finish war", outcome: "Impossible. You die April 12, 1945.")
                ]
            )
        ]
    }

    // MARK: - Missing administrations: JQ Adams through Coolidge

    static func jqAdamsCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"jqa_tariff_1828",title:"Tariff of Abominations",year:1828,
            description:"Congress passes the highest tariff in US history. Southern states threaten nullification — claiming states can void federal laws. John C. Calhoun (your VP) is secretly leading opposition. This sets the stage for the Civil War.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Sign the tariff into law",outcome:"Economy improves in North. South furious. Nullification crisis seeds planted."),
                HistoricalCrisisOption(title:"Veto the tariff",outcome:"Congress overrides. You appear weak. South only temporarily appeased."),
                HistoricalCrisisOption(title:"Propose compromise tariff",outcome:"Partial success. Sectional tensions reduced but not eliminated.")
            ])
    ]}

    static func vanBurenCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"vanburen_panic_1837",title:"Panic of 1837",year:1837,
            description:"Bank failures cascade across the country. One-third of Americans lose their jobs. Jackson's hard money policies and speculative land bubble have burst. The worst economic depression in US history begins.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Establish Independent Treasury",outcome:"Government separated from private banks. Economy slowly stabilizes. Deflationary pressure."),
                HistoricalCrisisOption(title:"Re-establish the National Bank",outcome:"Opposed by Democrats. Congress blocks you."),
                HistoricalCrisisOption(title:"Emergency government spending",outcome:"Heresy to Jacksonian principles. Party fractures.")
            ]),
        HistoricalCrisis(id:"vanburen_amistad_1839",title:"Amistad Crisis",year:1839,
            description:"Enslaved Africans seize the Spanish ship Amistad and are captured by US Navy off Long Island. Spain demands their return. Abolitionists demand their freedom. Former President John Quincy Adams will argue their case in Supreme Court.",
            countries:["USA","Cuba"],
            options:[
                HistoricalCrisisOption(title:"Return captives to Spain",outcome:"Diplomatic solution. Abolitionists outraged. Moral failure."),
                HistoricalCrisisOption(title:"Support their freedom",outcome:"Diplomatic crisis with Spain. Supreme Court ultimately frees them."),
                HistoricalCrisisOption(title:"Let courts decide",outcome:"Historical choice. Adams argues successfully before Supreme Court.")
            ])
    ]}

    static func harrisonCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"harrison_death_1841",title:"Presidential Death in Office",year:1841,
            description:"You are William Henry Harrison. You gave the longest inaugural address in history — 8,835 words — in freezing rain without a hat or coat. You now have severe pneumonia. Doctors are applying opium, castor oil, and leeches. You have 31 days left in your presidency.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Rest and recover",outcome:"You die April 4, 1841 after 31 days — shortest presidency in history."),
                HistoricalCrisisOption(title:"Continue governing through illness",outcome:"You die April 4, 1841. Your stubbornness becomes legend."),
                HistoricalCrisisOption(title:"Resign and hand power to Tyler",outcome:"Unprecedented. Historically impossible — you don't do this."),
                HistoricalCrisisOption(title:"Accept modern treatment",outcome:"This is 1841. There is no modern treatment. You die.")
            ])
    ]}

    static func tylerCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"tyler_texas_1845",title:"Texas Annexation",year:1845,
            description:"Texas has been an independent republic for 9 years and wants to join the United States. Mexico warns annexation means war. Northern states fear adding another slave state. Britain is courting Texas as an ally to block US expansion.",
            countries:["USA","MEX"],
            options:[
                HistoricalCrisisOption(title:"Annex Texas by joint resolution",outcome:"Historical choice. Texas joins USA. Mexican-American War follows under Polk."),
                HistoricalCrisisOption(title:"Negotiate with Mexico first",outcome:"Delay. Mexico refuses to accept Texan independence."),
                HistoricalCrisisOption(title:"Reject annexation",outcome:"Texas remains independent. Britain gains influence. Manifest Destiny stalled.")
            ])
    ]}

    static func taylorCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"taylor_california_1849",title:"California Statehood Crisis",year:1849,
            description:"California wants to join as a free state after the Gold Rush. The Senate is split 15-15 free vs slave. Southern states threaten secession if California admitted as free. The Compromise of 1850 is being negotiated. You oppose the compromise.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Admit California immediately",outcome:"You threaten to hang secessionists. South furious. You die July 9, 1850 before resolution."),
                HistoricalCrisisOption(title:"Support Clay's Compromise of 1850",outcome:"Kicking the can down the road. War delayed 11 years."),
                HistoricalCrisisOption(title:"Allow Southern secession",outcome:"Catastrophic. Union dissolves immediately.")
            ])
    ]}

    static func fillmoreCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"fillmore_fugitive_1850",title:"Fugitive Slave Act",year:1850,
            description:"Part of the Compromise of 1850 requires Northern states to return escaped slaves. Northern abolitionists are outraged. Some Northern states pass personal liberty laws refusing compliance. The Union is fraying.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Enforce the Fugitive Slave Act vigorously",outcome:"Historical choice. Union preserved temporarily. North disgusted. 'Uncle Tom's Cabin' written as response."),
                HistoricalCrisisOption(title:"Refuse to enforce it",outcome:"Southern states begin secession immediately. Civil War in 1851."),
                HistoricalCrisisOption(title:"Negotiate a different compromise",outcome:"Sectional tensions impossible to resolve. War delayed but not prevented.")
            ])
    ]}

    static func pierceCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"pierce_bleeding_kansas_1856",title:"Bleeding Kansas",year:1856,
            description:"Kansas Territory erupts in guerrilla warfare between pro-slavery and anti-slavery settlers. Pro-slavery forces sack the town of Lawrence. Abolitionist John Brown massacres pro-slavery settlers at Pottawatomie. Both sides claim Kansas.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Support pro-slavery Lecompton Constitution",outcome:"Historical failure. Kansas becomes a free state anyway. Democratic Party splits."),
                HistoricalCrisisOption(title:"Send federal troops for neutrality",outcome:"Violence continues. Neither side satisfied. Civil War closer."),
                HistoricalCrisisOption(title:"Allow Kansas to vote freely",outcome:"Anti-slavery settlers win. South threatens secession immediately.")
            ])
    ]}

    static func buchananCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"buchanan_secession_1860",title:"Southern Secession",year:1860,
            description:"Lincoln has just won the election. South Carolina has voted to secede. More Southern states are following. Your Attorney General says you cannot legally stop secession but you also cannot recognize it. Fort Sumter is being surrounded. You have 4 months left as president.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Do nothing — let Lincoln handle it",outcome:"Historical choice. Paralyzed presidency. Civil War begins under Lincoln."),
                HistoricalCrisisOption(title:"Use military force to prevent secession",outcome:"War starts under you. Lincoln inherits different situation."),
                HistoricalCrisisOption(title:"Recognize Confederate independence",outcome:"Union collapses. Lincoln inherits rump USA. Your legacy destroyed."),
                HistoricalCrisisOption(title:"Negotiate last-minute compromise",outcome:"Crittenden Compromise fails. Congress cannot agree. War inevitable.")
            ])
    ]}

    static func ajohnsonCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"ajohnson_impeachment_1868",title:"Impeachment of Andrew Johnson",year:1868,
            description:"You fired Secretary of War Stanton in violation of the Tenure of Office Act. The Radical Republican Congress has impeached you. The Senate trial begins. Chief Justice Salmon Chase presides. If convicted, you are removed from office. The future of Reconstruction hangs on the vote.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Defy the Senate and refuse removal",outcome:"Constitutional crisis. Military may intervene."),
                HistoricalCrisisOption(title:"Resign before conviction",outcome:"Unprecedented. Reconstruction remains uncertain."),
                HistoricalCrisisOption(title:"Fight the charges legally",outcome:"Historical choice. Acquitted by ONE vote (35-19, needed 36). You survive but Reconstruction damaged.")
            ])
    ]}

    static func grantCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"grant_black_friday_1869",title:"Black Friday Gold Panic",year:1869,
            description:"Speculators Jay Gould and James Fisk are cornering the gold market with help from your brother-in-law. They're trying to prevent the government from selling gold reserves. The economy is at risk. Your Treasury Secretary needs your authorization to release government gold.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Release government gold to break the corner",outcome:"Historical choice. Gold crashes from $162 to $133. Speculators ruined. Economy stabilizes but Grant tainted."),
                HistoricalCrisisOption(title:"Delay — investigate first",outcome:"Market continues to spiral. More economic damage."),
                HistoricalCrisisOption(title:"Arrest Gould and Fisk",outcome:"Legal process slow. Market damage done. Political scandal.")
            ])
    ]}

    static func hayesCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"hayes_railroad_1877",title:"Great Railroad Strike",year:1877,
            description:"The worst labor unrest in US history. Railroad workers strike after a 10% pay cut — the third such cut. Riots in Baltimore, Pittsburgh, Chicago, St. Louis. State militias are overwhelmed. Workers are burning railroad property. Federal troops are needed but this sets a dangerous precedent.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Send federal troops to break the strike",outcome:"Historical choice. Strike crushed. 100 dead. Labor movement grows stronger from martyrdom."),
                HistoricalCrisisOption(title:"Negotiate with workers",outcome:"Unprecedented. Railroad companies outraged. Strike ends but resentment festers."),
                HistoricalCrisisOption(title:"Let states handle it",outcome:"Violence spreads. Economy collapses. Anarchy in major cities.")
            ])
    ]}

    static func garfieldCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"garfield_assassination_1881",title:"Assassination of President Garfield",year:1881,
            description:"You are James Garfield. Charles Guiteau — a disappointed office-seeker who believed he was owed an ambassadorship — just shot you twice at the Baltimore and Potomac train station. You are still alive. The bullet near your spine may be extractable. Alexander Graham Bell is trying to locate it with a metal detector. Your doctors keep probing the wound with unsterilized fingers.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Refuse further medical treatment",outcome:"You linger 79 days, likely dying of infection from doctors. September 19, 1881."),
                HistoricalCrisisOption(title:"Let Bell's device find the bullet",outcome:"Historical attempt. Fails — metal springs in mattress interfere."),
                HistoricalCrisisOption(title:"Demand sterile surgical technique",outcome:"Germ theory not yet accepted by your doctors. Ignored."),
                HistoricalCrisisOption(title:"Accept fate",outcome:"You die September 19, 1881. Chester Arthur becomes president.")
            ])
    ]}

    static func arthurCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"arthur_civil_service_1883",title:"Civil Service Reform",year:1883,
            description:"The spoils system — rewarding political supporters with government jobs — has produced an assassination. Garfield's killer was a disappointed patronage-seeker. Congress is pushing the Pendleton Civil Service Act to create merit-based government employment. Your own political machine depends on patronage.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Sign the Pendleton Act",outcome:"Historical choice. You betray the machine that made you. Professional civil service created. Your political career ends but your legacy improves."),
                HistoricalCrisisOption(title:"Veto civil service reform",outcome:"Political machine preserved. Spoils system continues. Corruption entrenched."),
                HistoricalCrisisOption(title:"Propose weaker reform",outcome:"Compromise. Some improvement. Machine partially preserved.")
            ])
    ]}

    static func clevelandFirstCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"cleveland1_railroad_1886",title:"Interstate Commerce Act",year:1886,
            description:"Railroad monopolies are charging farmers ruinous rates, discriminating between shippers, and corrupting state legislatures. The Supreme Court just ruled states cannot regulate interstate commerce. Only Congress can act. Congress passes the Interstate Commerce Act. Do you sign the first federal regulation of a private industry?",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Sign the Interstate Commerce Act",outcome:"Historical choice. First federal regulation of private business. Weak enforcement initially but precedent set."),
                HistoricalCrisisOption(title:"Veto as federal overreach",outcome:"Railroad abuses continue. Populist movement explodes. Depression of 1890s worse."),
                HistoricalCrisisOption(title:"Strengthen the bill first",outcome:"Industry lobbying kills stronger version. Weak version passes anyway.")
            ])
    ]}

    static func harrisonBenjaminCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"harrisonb_wounded_knee_1890",title:"Wounded Knee Massacre",year:1890,
            description:"The Ghost Dance religious movement has spread among Sioux, promising restoration of their world. Nervous troops attempted to arrest Sitting Bull — he was killed. Now 350 Lakota Sioux, including women and children, are surrounded by the 7th Cavalry at Wounded Knee Creek. Tension is at maximum.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Allow Army to disarm the Sioux",outcome:"Historical outcome. 250-300 Sioux killed in chaos. Wounded Knee becomes symbol of American genocide."),
                HistoricalCrisisOption(title:"Withdraw troops, negotiate",outcome:"Tensions de-escalate. Ghost Dance fades naturally. Less bloodshed."),
                HistoricalCrisisOption(title:"Declare martial law over the region",outcome:"Full military occupation. Cultural suppression. Long-term resentment.")
            ])
    ]}

    static func clevelandSecondCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"cleveland2_panic_1893",title:"Panic of 1893",year:1893,
            description:"The worst economic depression before the Great Depression. 15,000 businesses failed, 500 banks closed, 20% unemployment. The silver vs gold standard debate is tearing the country apart. Populists demand silver coinage. Bankers demand the gold standard. Jacob Coxey is marching 500 unemployed workers on Washington.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Repeal Sherman Silver Purchase Act, defend gold",outcome:"Historical choice. Depression continues but currency stable. Bryan runs against gold standard in 1896."),
                HistoricalCrisisOption(title:"Allow silver coinage — inflate the currency",outcome:"Inflation helps debtors. Gold standard abandoned. International confidence shattered."),
                HistoricalCrisisOption(title:"Emergency public works programs",outcome:"Heresy to Bourbon Democrats. Congress refuses.")
            ])
    ]}

    static func mckinleyCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"mckinley_philippines_1899",title:"Philippine-American War",year:1899,
            description:"You acquired the Philippines from Spain for $20 million after the Spanish-American War. Emilio Aguinaldo and the Filipino independence movement now fight against American colonization. 126,000 US troops are deployed. Filipino guerrillas use tactics that will be familiar in Vietnam. Mark Twain leads the Anti-Imperialist League against you.",
            countries:["USA","PHL"],
            options:[
                HistoricalCrisisOption(title:"Continue military pacification",outcome:"Historical choice. 4,200 Americans, 20,000 Filipino fighters, 200,000+ Filipino civilians dead. Philippines becomes US territory."),
                HistoricalCrisisOption(title:"Grant Philippine independence",outcome:"American prestige hurt. Anti-imperialists vindicated. Philippines spared decades of colonial rule."),
                HistoricalCrisisOption(title:"Negotiate autonomy, not independence",outcome:"Compromise. Resistance continues but reduced.")
            ])
    ]}

    static func taftCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"taft_ballinger_1909",title:"Ballinger-Pinchot Controversy",year:1909,
            description:"Interior Secretary Ballinger is accused of favoring corporate interests in Alaskan coal lands. Forestry Chief Pinchot — Theodore Roosevelt's conservation champion — publicly challenges Ballinger. Roosevelt is watching from Africa. This is tearing the Republican Party apart and pushing TR toward a third party run.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Fire Pinchot for insubordination",outcome:"Historical choice. TR furious. Bull Moose Party formed 1912. Democrats win in three-way split."),
                HistoricalCrisisOption(title:"Fire Ballinger for corruption",outcome:"Party base outraged. Still can't stop TR's 1912 run."),
                HistoricalCrisisOption(title:"Investigate both men publicly",outcome:"Scandal expands. Loses either way.")
            ])
    ]}

    static func hardingCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"harding_teapot_dome_1922",title:"Teapot Dome Scandal",year:1922,
            description:"Your Interior Secretary Albert Fall has secretly leased Navy petroleum reserves at Teapot Dome to private oil companies in exchange for bribes. The Senate is investigating. Your friends are corrupt. Your administration is unraveling.",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Protect your friends",outcome:"Scandal explodes. Fall becomes first Cabinet member imprisoned. Your legacy destroyed."),
                HistoricalCrisisOption(title:"Fire Fall immediately, cooperate",outcome:"Damage limited. You die August 2, 1923 before full exposure — possibly from the stress."),
                HistoricalCrisisOption(title:"Resign before scandal breaks",outcome:"Unprecedented. Coolidge avoids taint.")
            ])
    ]}

    static func coolidgeCrises() -> [HistoricalCrisis] {[
        HistoricalCrisis(id:"coolidge_mississippi_1927",title:"Great Mississippi Flood",year:1927,
            description:"The worst natural disaster in US history. 27,000 square miles flooded. 500,000 African Americans driven from their homes. Commerce Secretary Herbert Hoover runs the relief effort masterfully, making him a national hero. You must decide the federal response — intervention or leave it to states?",
            countries:["USA"],
            options:[
                HistoricalCrisisOption(title:"Federal emergency response",outcome:"Unprecedented federal intervention in disaster relief. Hoover becomes famous. Sets template for future disaster response."),
                HistoricalCrisisOption(title:"Leave it to states and charities",outcome:"Historical tendency. Suffering prolonged. Red Cross and Hoover fill the gap. Racial discrimination in relief."),
                HistoricalCrisisOption(title:"Hoover leads all-hands response",outcome:"Historical outcome. Herbert Hoover's national profile soars. He wins presidency in 1928.")
            ])
    ]}
}
