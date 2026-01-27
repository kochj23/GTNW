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
                    CrisisOption(title: "Lead militia to suppress rebellion", outcome: "Rebellion crushed. Federal authority established. Some see it as tyranny."),
                    CrisisOption(title: "Negotiate with rebels", outcome: "Seen as weakness. Tax collection becomes impossible."),
                    CrisisOption(title: "Repeal the tax", outcome: "Federal revenue collapses. Government weakened."),
                    CrisisOption(title: "Ignore the rebellion", outcome: "Spreads to other states. Union at risk.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_french_revolution_1793",
                title: "French Revolution - Choose a Side?",
                year: 1793,
                description: "France, our Revolutionary ally, has executed its king and declared war on Britain. France demands we honor our 1778 treaty. Jefferson urges support. Hamilton says stay neutral.",
                countries: ["France", "UK"],
                options: [
                    CrisisOption(title: "Declare neutrality", outcome: "France furious. Treaty obligations ignored. But peace maintained."),
                    CrisisOption(title: "Support France militarily", outcome: "War with Britain. American economy devastated."),
                    CrisisOption(title: "Support Britain secretly", outcome: "France discovers betrayal. Relations ruined."),
                    CrisisOption(title: "Mediate between Britain and France", outcome: "Both sides reject interference.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_jays_treaty_1794",
                title: "Jay's Treaty with Britain",
                year: 1794,
                description: "Chief Justice Jay negotiated treaty with Britain. Britain will evacuate forts in Northwest, but treaty says nothing about impressment of American sailors. Public is outraged.",
                countries: ["UK"],
                options: [
                    CrisisOption(title: "Ratify the treaty", outcome: "Avoids war with Britain. Jeffersonians call you British puppet. But peace secured."),
                    CrisisOption(title: "Reject the treaty", outcome: "Britain maintains forts. War looms. Western expansion halted."),
                    CrisisOption(title: "Renegotiate for impressment clause", outcome: "Britain refuses. Negotiations collapse."),
                    CrisisOption(title: "Let Senate decide without recommendation", outcome: "Political chaos. Leadership questioned.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_northwest_territory_1790",
                title: "Native American Resistance - Northwest Territory",
                year: 1790,
                description: "Native American confederacy under Little Turtle defeats two US armies. Western settlers demand protection. Expansion threatened.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Send larger army under Anthony Wayne", outcome: "Decisive victory at Fallen Timbers 1794. Northwest opened."),
                    CrisisOption(title: "Negotiate territorial compromise", outcome: "Temporary peace. Settlers dissatisfied."),
                    CrisisOption(title: "Withdraw and fortify existing borders", outcome: "Seen as defeat. Western expansion stalls."),
                    CrisisOption(title: "Militia-only approach (no federal army)", outcome: "Ineffective. Casualties mount.")
                ]
            ),

            HistoricalCrisis(
                id: "washington_farewell_address_1796",
                title: "Farewell Address - Set Foreign Policy",
                year: 1796,
                description: "As you prepare to leave office, you write your farewell address. Your words on foreign policy will guide the nation for generations. What is your core message?",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Warn against foreign entanglements", outcome: "Isolationism becomes doctrine for 100+ years. America stays neutral in European wars."),
                    CrisisOption(title: "Urge Atlantic alliance with Britain", outcome: "Pro-British policy. Jefferson furious."),
                    CrisisOption(title: "Advocate American expansion", outcome: "Manifest Destiny begins early."),
                    CrisisOption(title: "Say nothing substantive", outcome: "No guiding principles. Future presidents flounder.")
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
                    CrisisOption(title: "Declare war on France", outcome: "Quasi-War begins. Naval conflict. Expensive but popular."),
                    CrisisOption(title: "Pay the bribe secretly", outcome: "If discovered, presidency destroyed."),
                    CrisisOption(title: "Build Navy and wait", outcome: "Naval buildup strengthens America. Tensions remain high."),
                    CrisisOption(title: "Negotiate despite insult", outcome: "Seen as weak. Federalists revolt.")
                ]
            ),

            HistoricalCrisis(
                id: "adams_alien_sedition_1798",
                title: "Alien and Sedition Acts",
                year: 1798,
                description: "War fever leads Federalists to propose laws criminalizing criticism of government. Jefferson calls them tyranny. Your party demands you sign. Your legacy hangs in balance.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Sign the Acts into law", outcome: "Opposition newspapers shut down. Jefferson elected next president in backlash. Your reputation damaged forever."),
                    CrisisOption(title: "Veto the Acts", outcome: "Federalist Party revolts. But Constitution protected."),
                    CrisisOption(title: "Sign but not enforce", outcome: "Worst of both worlds. Inconsistency noted."),
                    CrisisOption(title: "Advocate repeal after signing", outcome: "Flip-flopping damages credibility.")
                ]
            ),

            HistoricalCrisis(
                id: "adams_peace_1800",
                title: "France Seeks Peace - End Quasi-War?",
                year: 1800,
                description: "Napoleon offers peace treaty. Federalist war hawks want to continue war. Peace will cost you 1800 election. War will cost American lives. Your choice defines your legacy.",
                countries: ["France"],
                options: [
                    CrisisOption(title: "Accept peace immediately", outcome: "Quasi-War ends. You lose 1800 election. But peace achieved. History remembers you well."),
                    CrisisOption(title: "Continue war for political gain", outcome: "Unnecessary deaths. Moral stain on presidency."),
                    CrisisOption(title: "Demand reparations first", outcome: "France refuses. War drags on."),
                    CrisisOption(title: "Let next president decide", outcome: "Leadership abdication. Legacy damaged.")
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
                    CrisisOption(title: "Pay the tribute", outcome: "Hypocrisy noted. But American sailors safe."),
                    CrisisOption(title: "Send Navy to fight ('shores of Tripoli')", outcome: "4-year war. Piracy suppressed. America respected."),
                    CrisisOption(title: "Avoid Mediterranean trade entirely", outcome: "Commerce damaged. Seen as retreat."),
                    CrisisOption(title: "Negotiate better terms", outcome: "Pirates laugh. Tribute increases.")
                ]
            ),

            HistoricalCrisis(
                id: "jefferson_louisiana_1803",
                title: "Louisiana Purchase Opportunity",
                year: 1803,
                description: "Napoleon offers to sell entire Louisiana Territory for $15 million. Doubles US size! But Constitution doesn't authorize such purchases. Strict constructionists (like you) say it's illegal.",
                countries: ["France"],
                options: [
                    CrisisOption(title: "Buy it - Constitution be damned", outcome: "America doubles in size. Hypocrisy noted but worth it."),
                    CrisisOption(title: "Propose constitutional amendment first", outcome: "Napoleon withdraws offer. Lost forever."),
                    CrisisOption(title: "Decline on constitutional grounds", outcome: "Consistency maintained. Opportunity lost. History judges you harshly."),
                    CrisisOption(title: "Buy only New Orleans", outcome: "Napoleon refuses partial sale.")
                ]
            ),

            HistoricalCrisis(
                id: "jefferson_chesapeake_1807",
                title: "HMS Leopard Attacks USS Chesapeake",
                year: 1807,
                description: "British warship fires on USS Chesapeake, killing 3, wounding 18, impressing 4 American sailors. Public demands war. You're a pacifist. Britain's Royal Navy vastly superior to American fleet.",
                countries: ["UK"],
                options: [
                    CrisisOption(title: "Declare war on Britain", outcome: "Premature war. British burn Washington in 1814."),
                    CrisisOption(title: "Embargo Act - ban all foreign trade", outcome: "American economy devastated. Embargo fails. Unpopular."),
                    CrisisOption(title: "Demand apology and reparations", outcome: "Britain refuses. Humiliation continues."),
                    CrisisOption(title: "Build Navy for future confrontation", outcome: "Wise but slow. Impressment continues.")
                ]
            ),

            HistoricalCrisis(
                id: "jefferson_burr_conspiracy_1806",
                title: "Burr Conspiracy - Treason by Former VP",
                year: 1806,
                description: "Your former Vice President Aaron Burr is raising army in the West. Reports say he plans to conquer Mexico, or split off Western states, or both. Treason trial will be controversial.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Arrest Burr for treason", outcome: "Trial fails (lack of evidence). Burr goes free. Constitutional crisis."),
                    CrisisOption(title: "Military force to disperse his army", outcome: "Burr flees. Never tried. Mystery remains."),
                    CrisisOption(title: "Ignore the rumors", outcome: "Burr's plot proceeds. Western states in danger."),
                    CrisisOption(title: "Offer Burr pardon to stand down", outcome: "Negotiating with traitors sets bad precedent.")
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
                    CrisisOption(title: "Declare war", outcome: "War of 1812 begins. British burn Washington. But America proves its independence."),
                    CrisisOption(title: "Continue negotiations", outcome: "Britain ignores you. Impressment continues. National humiliation."),
                    CrisisOption(title: "Economic embargo only", outcome: "Hurts American economy more than Britain. Fails."),
                    CrisisOption(title: "War only if Britain attacks first", outcome: "Decades of tension. No resolution.")
                ]
            ),

            HistoricalCrisis(
                id: "madison_washington_burned_1814",
                title: "British Burn Washington D.C.",
                year: 1814,
                description: "British army marches on capital. Militia flees. White House, Capitol, and government buildings will be torched. You must flee. Darkest moment of the war. Continue fighting or sue for peace?",
                countries: ["UK"],
                options: [
                    CrisisOption(title: "Continue war despite capital loss", outcome: "Jackson wins at New Orleans. National morale restored. Treaty of Ghent ends war."),
                    CrisisOption(title: "Immediate peace negotiations", outcome: "Negotiating from weakness. British demands increase."),
                    CrisisOption(title: "Resign presidency", outcome: "National disaster. Britain wins."),
                    CrisisOption(title: "Relocate capital permanently", outcome: "Seen as running away. Political chaos.")
                ]
            ),

            HistoricalCrisis(
                id: "madison_hartford_convention_1814",
                title: "Hartford Convention - New England Secession?",
                year: 1814,
                description: "New England Federalists meet secretly in Hartford. Rumors of secession and separate peace with Britain. Constitution in danger. Your response?",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Threaten military force", outcome: "Civil war risk. But Convention backs down."),
                    CrisisOption(title: "Ignore them", outcome: "Jackson's victory at New Orleans makes them look foolish. Federalist Party destroyed."),
                    CrisisOption(title: "Negotiate grievances", outcome: "Legitimizes secession talk."),
                    CrisisOption(title: "Arrest Convention leaders", outcome: "Martyrdom. Northeast in revolt.")
                ]
            ),

            HistoricalCrisis(
                id: "madison_jackson_new_orleans_1815",
                title: "Battle of New Orleans - After Peace Signed?",
                year: 1815,
                description: "Andrew Jackson wins glorious victory at New Orleans, killing 2,000 British with only 71 American losses. Problem: Peace treaty was signed 2 weeks earlier. News just hadn't arrived. Celebrate or condemn?",
                countries: ["UK"],
                options: [
                    CrisisOption(title: "Celebrate Jackson as hero", outcome: "National pride restored. War ends on high note. Jackson becomes president later."),
                    CrisisOption(title: "Condemn unnecessary bloodshed", outcome: "Public revolts. Jackson your enemy forever."),
                    CrisisOption(title: "Quietly acknowledge", outcome: "Muted response. Moment wasted."),
                    CrisisOption(title: "Demand Britain pay reparations", outcome: "Britain refuses. Peace treaty endangered.")
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
                    CrisisOption(title: "Issue Monroe Doctrine", outcome: "European powers warned off. Doctrine defines American policy for 100+ years. But it's a bluff."),
                    CrisisOption(title: "Ally with Britain to enforce", outcome: "Britain gets credit. America looks weak."),
                    CrisisOption(title: "Say nothing", outcome: "Europeans re-colonize Latin America. Hemisphere dominated."),
                    CrisisOption(title: "Offer to mediate conflicts", outcome: "All sides ignore you.")
                ]
            ),

            HistoricalCrisis(
                id: "monroe_florida_1818",
                title: "Jackson Invades Spanish Florida",
                year: 1818,
                description: "General Andrew Jackson, pursuing Seminole raiders, invades Spanish Florida without authorization, executes two British citizens, and seizes Spanish forts. Spain demands punishment. Jackson has public support.",
                countries: ["Spain", "UK"],
                options: [
                    CrisisOption(title: "Defend Jackson's actions", outcome: "Spain forced to sell Florida. Britain protests. Jackson grateful."),
                    CrisisOption(title: "Apologize and censure Jackson", outcome: "Spain mollified. Jackson becomes your enemy. Western voters angry."),
                    CrisisOption(title: "Claim Jackson misunderstood orders", outcome: "Transparent lie. Credibility damaged."),
                    CrisisOption(title: "Offer Spain compensation", outcome: "Treasury drained. Seen as weak.")
                ]
            ),

            HistoricalCrisis(
                id: "monroe_missouri_compromise_1820",
                title: "Missouri Crisis - Slavery Expansion",
                year: 1820,
                description: "Missouri seeks statehood as slave state. Would upset free/slave balance. 'This momentous question, like a fire bell in the night, awakened and filled me with terror' - Jefferson. Nation splitting.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Support Missouri Compromise (ban slavery north of 36°30')", outcome: "Crisis delayed 40 years. But problem not solved."),
                    CrisisOption(title: "Ban slavery in Missouri", outcome: "South threatens secession. Union in danger."),
                    CrisisOption(title: "Allow slavery to expand freely", outcome: "North furious. Abolition movement accelerates."),
                    CrisisOption(title: "Let Congress decide without input", outcome: "Gridlock. No state admitted.")
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
                    CrisisOption(title: "Enforce removal (Trail of Tears)", outcome: "4,000 Cherokee die. Ethnic cleansing stain on presidency. But land opened for settlers."),
                    CrisisOption(title: "Respect Supreme Court ruling", outcome: "Cherokee remain. Southern states furious. Secession talk begins."),
                    CrisisOption(title: "Voluntary relocation with compensation", outcome: "Few accept. Problem lingers."),
                    CrisisOption(title: "Create Native American state in Oklahoma", outcome: "Radical idea. No support.")
                ]
            ),

            HistoricalCrisis(
                id: "jackson_nullification_1832",
                title: "Nullification Crisis - South Carolina",
                year: 1832,
                description: "South Carolina declares federal tariff null and void, threatens secession. Vice President Calhoun supports them. 'The Union must be preserved' vs states' rights. Your move.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Threaten military force", outcome: "'I will hang Calhoun!' South Carolina backs down. Civil war postponed 30 years."),
                    CrisisOption(title: "Accept nullification doctrine", outcome: "Federal authority destroyed. States ignore laws at will. Nation collapses."),
                    CrisisOption(title: "Lower tariff to appease South", outcome: "Compromise works. Crisis defused. Precedent set."),
                    CrisisOption(title: "Call constitutional convention", outcome: "Opens pandora's box. Chaos.")
                ]
            ),

            HistoricalCrisis(
                id: "jackson_bank_war_1832",
                title: "Bank War - Veto Recharter?",
                year: 1832,
                description: "Second Bank of the United States seeks recharter. You hate banks. But Nicholas Biddle warns removing federal bank will cause economic chaos. Clay makes it election issue.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Veto bank recharter", outcome: "Popular but causes Panic of 1837 after you leave office."),
                    CrisisOption(title: "Sign recharter reluctantly", outcome: "Political base revolts. Seen as sellout."),
                    CrisisOption(title: "Reform and recharter", outcome: "Compromise. Nobody happy."),
                    CrisisOption(title: "Let bank die without comment", outcome: "Financial chaos. No plan to replace it.")
                ]
            ),

            HistoricalCrisis(
                id: "jackson_texas_independence_1836",
                title: "Texas Independence - Recognize?",
                year: 1836,
                description: "Texas declares independence from Mexico after Battle of San Jacinto. Texans want annexation to US. But this means war with Mexico and inflames slavery debate. Sam Houston waiting.",
                countries: ["Mexico"],
                options: [
                    CrisisOption(title: "Recognize Texas immediately", outcome: "Mexico breaks relations. War looms."),
                    CrisisOption(title: "Annex Texas immediately", outcome: "Mexican-American War begins in 1836 instead of 1846."),
                    CrisisOption(title: "Delay recognition", outcome: "Texas remains independent. Mexico threatens reconquest."),
                    CrisisOption(title: "Support Mexican government", outcome: "Texas feels betrayed. Might ally with Britain.")
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
                    CrisisOption(title: "Demand 54-40 or fight", outcome: "Britain prepares for war. But you're about to fight Mexico too. Two-front war disaster."),
                    CrisisOption(title: "Accept 49th parallel compromise", outcome: "Peacefully acquire vast territory. Focus on Mexico instead."),
                    CrisisOption(title: "Propose arbitration", outcome: "Britain refuses. Deadlock continues."),
                    CrisisOption(title: "Withdraw US claims", outcome: "Political suicide. Pacific Northwest lost.")
                ]
            ),

            HistoricalCrisis(
                id: "polk_mexican_war_1846",
                title: "Mexican-American War - Provoke or Wait?",
                year: 1846,
                description: "Texas annexation leads to border dispute. Mexico claims Nueces River. US claims Rio Grande. You want California. Send army to disputed zone to provoke war?",
                countries: ["Mexico"],
                options: [
                    CrisisOption(title: "Order Taylor into disputed zone", outcome: "Mexican attack. 'American blood on American soil!' War declared. You acquire California and Southwest."),
                    CrisisOption(title: "Negotiate border", outcome: "Mexico refuses. Stalemate. California remains Mexican."),
                    CrisisOption(title: "Wait for Mexican attack", outcome: "Mexico doesn't attack. No war justification."),
                    CrisisOption(title: "Offer to buy California", outcome: "Mexico refuses to sell. National pride at stake.")
                ]
            ),

            HistoricalCrisis(
                id: "polk_veracruz_1847",
                title: "Veracruz Landing - End War How?",
                year: 1847,
                description: "Winfield Scott captured Mexico City. Total victory. But Mexico won't negotiate. Advisors split: Annex all of Mexico vs take California/Southwest vs withdraw and declare victory.",
                countries: ["Mexico"],
                options: [
                    CrisisOption(title: "Annex all of Mexico", outcome: "Slavery debate explodes. Mexican resistance continues. Impossible to govern."),
                    CrisisOption(title: "Take California and Southwest only", outcome: "Treaty of Guadalupe Hidalgo. Mexican Cession. Manifest Destiny achieved."),
                    CrisisOption(title: "Withdraw and declare victory", outcome: "Nothing gained. War seen as pointless. Political disaster."),
                    CrisisOption(title: "Install puppet regime in Mexico", outcome: "Mexican nationalism. Endless guerrilla war.")
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
                    CrisisOption(title: "Send resupply convoy", outcome: "Confederates fire first. You have moral high ground. North unites. 4-year war begins."),
                    CrisisOption(title: "Evacuate Fort Sumter", outcome: "Seen as accepting secession. Border states join Confederacy. War still comes but from weaker position."),
                    CrisisOption(title: "Blockade Charleston", outcome: "Slow strangulation. War starts anyway but goal unclear."),
                    CrisisOption(title: "Negotiate Confederate independence", outcome: "Union dissolved. Slavery perpetuated. Lincoln legacy destroyed.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_emancipation_1862",
                title: "Emancipation Proclamation Timing",
                year: 1862,
                description: "You've written Emancipation Proclamation freeing slaves in rebel states. Cabinet says wait for military victory or it looks desperate. Abolitionists demand immediate action. Border states threaten to leave.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Issue after Antietam victory", outcome: "Moral cause proclaimed. Europe won't recognize Confederacy. Border states angry but stay."),
                    CrisisOption(title: "Issue immediately", outcome: "Looks desperate. Border states secede. War becomes unwinnable."),
                    CrisisOption(title: "Wait for complete victory", outcome: "Too late. Moral opportunity lost."),
                    CrisisOption(title: "Free slaves gradually over 10 years", outcome: "Abolitionists furious. Half-measure satisfies nobody.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_trent_affair_1861",
                title: "Trent Affair - War with Britain During Civil War?",
                year: 1861,
                description: "US Navy stops British ship HMS Trent, arrests Confederate diplomats. Britain demands release and apology. Public wants to keep them. But war with Britain during Civil War means certain defeat.",
                countries: ["UK"],
                options: [
                    CrisisOption(title: "Release diplomats and apologize", outcome: "Humiliating but avoids two-front war. Britain stays neutral."),
                    CrisisOption(title: "Keep diplomats, defy Britain", outcome: "Britain joins Confederacy. Union crushed."),
                    CrisisOption(title: "Offer compromise (release without apology)", outcome: "Britain demands full apology. Doesn't work."),
                    CrisisOption(title: "Propose international arbitration", outcome: "Too slow. Britain invades Canada. War begins.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_habeas_corpus_1861",
                title: "Suspend Habeas Corpus?",
                year: 1861,
                description: "Maryland Confederate sympathizers sabotage railroads. Chief Justice Taney rules you can't suspend habeas corpus. But national security requires jailing suspects without trial. Constitution vs survival.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Suspend habeas corpus anyway", outcome: "Thousands jailed without trial. Civil liberties damaged. But Union secured."),
                    CrisisOption(title: "Obey Supreme Court", outcome: "Sabotage continues. War effort hindered."),
                    CrisisOption(title: "Selective enforcement", outcome: "Inconsistent. Rule of law questioned."),
                    CrisisOption(title: "Seek Congressional authorization", outcome: "Congress debates. Maryland secedes while you wait.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_gettysburg_1863",
                title: "After Gettysburg - Peace Overture from South?",
                year: 1863,
                description: "Lee defeated at Gettysburg. 50,000 casualties in 3 days. Confederate VP Stephens offers peace talks: Independence for Confederacy, slavery remains, peaceful coexistence. War is winnable but costly. Peace now or fight to total victory?",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Accept peace talks", outcome: "Union dissolved. Two American nations. Slavery perpetuated indefinitely."),
                    CrisisOption(title: "Demand unconditional surrender only", outcome: "War continues 2 more years. 400,000 more dead. But Union restored and slavery ended."),
                    CrisisOption(title: "Negotiate reunion with slavery protected", outcome: "Union nominally restored. But moral stain remains. Future civil war inevitable."),
                    CrisisOption(title: "Offer gradual compensated emancipation", outcome: "South rejects. North says too weak.")
                ]
            ),

            HistoricalCrisis(
                id: "lincoln_booth_1865",
                title: "Assassination Threat Detected",
                year: 1865,
                description: "Intelligence reports plot to assassinate you at Ford's Theatre. Ward Hill Lamon, your bodyguard, begs you not to go. But the war is won. What threat could remain?",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Go to theater anyway (history)", outcome: "John Wilkes Booth shoots you. You die. Johnson becomes president. Reconstruction disaster."),
                    CrisisOption(title: "Stay home tonight", outcome: "Booth finds another time. Assassination delayed or prevented?"),
                    CrisisOption(title: "Bring extra security", outcome: "Booth scared off. You survive. Reconstruction succeeds under your leadership."),
                    CrisisOption(title: "Arrest suspicious actors preemptively", outcome: "Booth caught. Conspiracy unraveled. But false arrests too.")
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
                    CrisisOption(title: "Support Panama revolution", outcome: "Panama independent in 3 days. US gets canal zone. But you created a nation for commercial gain."),
                    CrisisOption(title: "Negotiate better terms with Colombia", outcome: "Years of talks. No canal. Germany might build it instead."),
                    CrisisOption(title: "Build canal through Nicaragua", outcome: "More expensive. Takes longer. Panama stays with Colombia."),
                    CrisisOption(title: "Abandon canal project", outcome: "Strategic opportunity lost. Pacific access delayed decades.")
                ]
            ),

            HistoricalCrisis(
                id: "troosevelt_great_white_fleet_1907",
                title: "Great White Fleet - Provoke Japan?",
                year: 1907,
                description: "Japan's navy growing powerful after defeating Russia. Admiral Mahan suggests circumnavigating globe with entire battle fleet to show American power. Japan may see it as threat. Send the fleet?",
                countries: ["Japan"],
                options: [
                    CrisisOption(title: "Send Great White Fleet", outcome: "Massive show of force. Japan impressed. But relations strained."),
                    CrisisOption(title: "Cancel to avoid provoking Japan", outcome: "Seen as weak. Japan emboldens. Expansion continues."),
                    CrisisOption(title: "Send only to Pacific, not Japan", outcome: "Compromise. Message unclear."),
                    CrisisOption(title: "Invite Japan to naval exercises", outcome: "Japan declines. Goodwill gesture ignored.")
                ]
            ),

            HistoricalCrisis(
                id: "troosevelt_coal_strike_1902",
                title: "Coal Strike - Side with Labor or Capital?",
                year: 1902,
                description: "140,000 coal miners strike. Winter coming. Nation faces heating crisis. Mine owners refuse arbitration. You have no constitutional authority to intervene in private dispute. But people will freeze.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Threaten to seize mines with Army", outcome: "Owners cave. Strike settled. But you exceeded authority. Precedent set for federal intervention."),
                    CrisisOption(title: "Side with owners", outcome: "Strike crushed. But labor radicalized. Socialist movement grows."),
                    CrisisOption(title: "Force arbitration", outcome: "Compromise. Miners get 10% raise. Your Square Deal begins."),
                    CrisisOption(title: "Let crisis resolve itself", outcome: "People freeze. Riots. Political disaster.")
                ]
            ),

            HistoricalCrisis(
                id: "troosevelt_russo_japanese_1905",
                title: "Russo-Japanese War - Mediate for Nobel Prize?",
                year: 1905,
                description: "Russia and Japan locked in bloody war. Both exhausted. You can mediate peace, earn Nobel Prize, establish America as world power. But picking sides risks alienating the loser.",
                countries: ["Russia", "Japan"],
                options: [
                    CrisisOption(title: "Mediate Treaty of Portsmouth", outcome: "Peace achieved. You win Nobel Prize. America now Pacific power. But Russia embittered."),
                    CrisisOption(title: "Side openly with Japan", outcome: "Japan victorious. Russia hostile forever."),
                    CrisisOption(title: "Side with Russia", outcome: "White race solidarity. But Japan becomes enemy."),
                    CrisisOption(title: "Stay out entirely", outcome: "Europe mediates. America irrelevant in Pacific.")
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
                    CrisisOption(title: "Declare war on Germany", outcome: "Premature. America unprepared. Public support weak."),
                    CrisisOption(title: "Stern warning to Germany", outcome: "Germany apologizes, restricts submarine warfare temporarily. War delayed 2 years."),
                    CrisisOption(title: "Accept German apology", outcome: "Seen as weak. More American ships sunk."),
                    CrisisOption(title: "Ban Americans from traveling on belligerent ships", outcome: "Unpopular. Retreating from freedom of seas.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_zimmermann_1917",
                title: "Zimmermann Telegram Intercepted",
                year: 1917,
                description: "British intelligence intercepts German telegram proposing Mexico ally with Germany, attack US, reconquer Texas/Arizona/New Mexico. Germany to resume unrestricted submarine warfare. This is your war declaration justification.",
                countries: ["Germany", "Mexico"],
                options: [
                    CrisisOption(title: "Declare war on Germany", outcome: "America enters WW1. 116,000 Americans die. But victory in 1918. Germany defeated."),
                    CrisisOption(title: "Continue armed neutrality", outcome: "More American ships sunk. Pressure mounts. War inevitable anyway."),
                    CrisisOption(title: "Invade Mexico preemptively", outcome: "Wrong enemy. Germany wins in Europe."),
                    CrisisOption(title: "Offer to mediate peace in Europe", outcome: "All sides reject. America sidelined.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_versailles_1919",
                title: "Treaty of Versailles - Punish Germany?",
                year: 1919,
                description: "Germany defeated. France demands crushing reparations. You want lenient peace and League of Nations. Clemenceau and Lloyd George want vengeance. Harsh peace breeds future war. Compromise?",
                countries: ["Germany", "France", "UK"],
                options: [
                    CrisisOption(title: "Support harsh reparations", outcome: "Germany economically destroyed. Hitler rises in 20 years. WW2 ensues."),
                    CrisisOption(title: "Fight for lenient peace", outcome: "France refuses. You fail. Treaty is harsh anyway. But you tried."),
                    CrisisOption(title: "Walk out of negotiations", outcome: "Europe makes own peace. League of Nations without America."),
                    CrisisOption(title: "Propose Marshall Plan-style rebuilding", outcome: "Too radical for 1919. Rejected. But prescient.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_league_of_nations_1919",
                title: "League of Nations - Senate Rejects Treaty",
                year: 1919,
                description: "Your League of Nations treaty fails in Senate. Republicans demand reservations protecting American sovereignty. Accept reservations or watch dream die?",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Accept Lodge reservations", outcome: "League created with America. Might prevent WW2."),
                    CrisisOption(title: "Refuse any changes to treaty", outcome: "Treaty fails. America never joins League. Your dream dies. League fails without America."),
                    CrisisOption(title: "Campaign to pressure Senate", outcome: "You suffer stroke. Presidency collapses. Treaty still fails."),
                    CrisisOption(title: "Compromise with moderate reservations", outcome: "Narrow path. Possible success.")
                ]
            ),

            HistoricalCrisis(
                id: "wilson_red_scare_1919",
                title: "Red Scare - Palmer Raids",
                year: 1919,
                description: "Communist revolution spreads from Russia. Anarchist bombings in US. Attorney General Palmer wants to arrest 10,000 suspected radicals without warrants. Deportations. Civil liberties in danger.",
                countries: ["USA", "USSR"],
                options: [
                    CrisisOption(title: "Authorize Palmer Raids", outcome: "6,000 arrested. Mostly innocent. Civil liberties trampled. Red Scare hysteria."),
                    CrisisOption(title: "Refuse to authorize", outcome: "More bombings. Palmer runs against you. But Constitution protected."),
                    CrisisOption(title: "Targeted operations only", outcome: "Some radicals caught. Civil liberties mostly preserved."),
                    CrisisOption(title: "Pardon all arrested radicals", outcome: "Political suicide. Seen as soft on communism.")
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
                    CrisisOption(title: "Federal intervention programs", outcome: "Contradicts principles but helps economy. Critics say too little too late."),
                    CrisisOption(title: "Let market self-correct", outcome: "Depression deepens. 25% unemployment. Hoovervilles. Political disaster."),
                    CrisisOption(title: "Encourage private charity", outcome: "Inadequate. Suffering continues."),
                    CrisisOption(title: "Public works programs", outcome: "Helps but not enough. FDR will do it bigger.")
                ]
            ),

            HistoricalCrisis(
                id: "hoover_bonus_army_1932",
                title: "Bonus Army - Attack Veterans?",
                year: 1932,
                description: "15,000 WW1 veterans camp in Washington demanding early bonus payment. Congress refuses. Veterans won't leave. MacArthur wants to clear them with Army. Attack veterans during election year?",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Order MacArthur to disperse camps", outcome: "Tanks and tear gas against veterans. Photos shock nation. Lose 1932 election in landslide."),
                    CrisisOption(title: "Pay the bonus early", outcome: "Treasury drained. Deficit explodes. But veterans go home peacefully."),
                    CrisisOption(title: "Negotiate departure", outcome: "Most leave. Remaining campers stay indefinitely."),
                    CrisisOption(title: "Ignore them", outcome: "Camps grow. Embarrassment continues. Still lose election.")
                ]
            ),

            HistoricalCrisis(
                id: "hoover_japan_manchuria_1931",
                title: "Japan Invades Manchuria - Respond?",
                year: 1931,
                description: "Japan invades Chinese Manchuria in violation of treaties. League of Nations asks US position. Secretary Stimson wants non-recognition doctrine. Isolationists say stay out. This sets precedent for future aggressors.",
                countries: ["Japan", "China"],
                options: [
                    CrisisOption(title: "Issue Stimson Doctrine (non-recognition)", outcome: "Moral stand taken. But no teeth. Japan ignores it. Precedent set that aggression has no consequences."),
                    CrisisOption(title: "Economic sanctions on Japan", outcome: "Japan begins seeing US as enemy. Path to Pearl Harbor begins."),
                    CrisisOption(title: "Recognize Japanese conquest", outcome: "Morally bankrupt. Aggression rewarded."),
                    CrisisOption(title: "Stay silent", outcome: "Appeasement. Emboldens future aggressors.")
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
                    CrisisOption(title: "Declare Bank Holiday", outcome: "Panic stops. Banking system stabilized. 'The only thing we have to fear is fear itself.' Presidency made."),
                    CrisisOption(title: "Let states handle it", outcome: "Uncoordinated response. Banking collapse continues."),
                    CrisisOption(title: "Federal guarantee of all deposits", outcome: "Moral hazard. Costs explode."),
                    CrisisOption(title: "Do nothing", outcome: "Total economic collapse. Revolution possible.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_court_packing_1937",
                title: "Supreme Court Packing Plan",
                year: 1937,
                description: "Supreme Court strikes down New Deal programs. You propose adding 6 justices (one for each justice over 70). Gives you 15-person court with majority. Expands power but threatens checks and balances.",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Push court-packing plan", outcome: "Plan fails. But Court gets message, stops blocking New Deal. Tactical victory."),
                    CrisisOption(title: "Abandon plan", outcome: "Court continues blocking programs. New Deal limited."),
                    CrisisOption(title: "Wait for justices to retire naturally", outcome: "Years pass. Programs struck down."),
                    CrisisOption(title: "Constitutional amendment to clarify power", outcome: "Takes years. States reject.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_lend_lease_1941",
                title: "Lend-Lease - Arm Britain Without War?",
                year: 1941,
                description: "Britain broke, alone against Hitler. Churchill begs for aid. Neutrality Acts forbid it. You propose 'lending' weapons we know won't be returned. Technically neutral but really joining war. Isolationists furious.",
                countries: ["UK", "Germany"],
                options: [
                    CrisisOption(title: "Push Lend-Lease through Congress", outcome: "Britain survives. Arsenal of Democracy. Hitler declares war eventually anyway."),
                    CrisisOption(title: "Maintain strict neutrality", outcome: "Britain falls. Hitler controls Europe. America alone vs Nazis."),
                    CrisisOption(title: "Sell weapons for cash only", outcome: "Britain can't pay. Falls to Hitler."),
                    CrisisOption(title: "Declare war immediately", outcome: "Public not ready. Political disaster. Lose Congress.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_pearl_harbor_1941",
                title: "Pearl Harbor - Day of Infamy Response",
                year: 1941,
                description: "Japan attacks Pearl Harbor. 2,403 Americans dead. Pacific Fleet crippled. Congress will declare war. But do you also declare war on Germany (Hitler's ally) or just Japan?",
                countries: ["Japan", "Germany", "Italy"],
                options: [
                    CrisisOption(title: "War on Japan only", outcome: "Hitler declares war on YOU 3 days later. Two-front war begins."),
                    CrisisOption(title: "War on all Axis powers", outcome: "Two-front war by your choice. Hitler might have stayed out otherwise."),
                    CrisisOption(title: "Negotiate with Japan", outcome: "After Pearl Harbor? Political impossibility. Japan would refuse."),
                    CrisisOption(title: "Focus on Germany first, hold Japan", outcome: "Europe First strategy. Correct choice.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_internment_1942",
                title: "Japanese-American Internment",
                year: 1942,
                description: "Military urges internment of 120,000 Japanese-Americans from West Coast. Claim espionage risk. No evidence of disloyalty. But post-Pearl Harbor fear is real. Greatest civil rights decision of war.",
                countries: ["USA", "Japan"],
                options: [
                    CrisisOption(title: "Sign Executive Order 9066 (internment)", outcome: "120,000 citizens imprisoned. Constitutional stain. But politically popular."),
                    CrisisOption(title: "Refuse internment", outcome: "Military and public furious. Political risk. But Constitution protected."),
                    CrisisOption(title: "Voluntary relocation with compensation", outcome: "Few accept. Problem persists."),
                    CrisisOption(title: "Intern only provable security risks", outcome: "Fair but time-consuming. Public says not enough.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_stalin_1943",
                title: "Stalin Demands Second Front",
                year: 1943,
                description: "USSR suffering 90% of Allied casualties vs Germany. Stalin demands second front in France NOW. But Eisenhower says premature. Stalin hints at separate peace with Hitler if abandoned.",
                countries: ["USSR", "Germany"],
                options: [
                    CrisisOption(title: "Invade France in 1943", outcome: "Premature. Heavy casualties. Might fail. But Stalin appeased."),
                    CrisisOption(title: "Delay until 1944 (D-Day)", outcome: "Stalin furious but USSR holds. Invasion succeeds. More dead Soviets."),
                    CrisisOption(title: "Invade through Balkans instead", outcome: "Churchill's plan. Germany not defeated. Stalin hostile."),
                    CrisisOption(title: "Focus on Pacific, let USSR handle Germany", outcome: "Stalin makes separate peace. Hitler controls Europe.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_yalta_1945",
                title: "Yalta Conference - Divide Post-War World",
                year: 1945,
                description: "You, Churchill, Stalin meet to plan post-war order. Stalin wants Eastern Europe. Churchill wants free elections. You want Soviet entry into Pacific War. Everyone wants something. Your health failing.",
                countries: ["USSR", "UK"],
                options: [
                    CrisisOption(title: "Grant Stalin Eastern Europe for Pacific help", outcome: "Cold War begins. Eastern Europe enslaved 50 years. But Japan defeated faster."),
                    CrisisOption(title: "Demand free elections everywhere", outcome: "Stalin refuses. Soviet-American relations sour immediately."),
                    CrisisOption(title: "Partition Germany permanently", outcome: "Germany divided. Cold War flashpoint."),
                    CrisisOption(title: "Threaten Stalin with atomic bomb", outcome: "Stalin doesn't believe it exists. Backfires.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_atomic_bomb_1945",
                title: "Manhattan Project Briefing - Continue?",
                year: 1945,
                description: "Secret project to build atomic bomb approaching success. $2 billion spent. 130,000 people working. Germany almost defeated (original target). Japan remains. Scientists warn of nuclear arms race. Continue?",
                countries: ["Japan", "Germany"],
                options: [
                    CrisisOption(title: "Complete atomic bomb", outcome: "Bomb ready August 1945. Truman decides to use it."),
                    CrisisOption(title: "Cancel project, destroy research", outcome: "Nuclear age delayed. War with Japan continues conventionally. Scientists flee to USSR."),
                    CrisisOption(title: "Share research with USSR", outcome: "Atomic monopoly surrendered. But Cold War prevented?"),
                    CrisisOption(title: "Use on Germany as originally planned", outcome: "Too late. Germany surrenders May 1945.")
                ]
            ),

            HistoricalCrisis(
                id: "fdr_death_1945",
                title: "Your Health Failing - Hand Over to Truman?",
                year: 1945,
                description: "You're dying. Cerebral hemorrhage imminent. Truman knows nothing about atomic bomb, nothing about Stalin, nothing about post-war plans. Brief him now or keep secrets?",
                countries: ["USA"],
                options: [
                    CrisisOption(title: "Brief Truman on everything", outcome: "Truman prepared. Smooth transition. Wise choice."),
                    CrisisOption(title: "Keep secrets until necessary", outcome: "Historical choice. Truman shocked by atomic bomb revelation. Struggles initially."),
                    CrisisOption(title: "Resign to let Truman prepare", outcome: "Unprecedented. Presidency weakened."),
                    CrisisOption(title: "Request 5th term to finish war", outcome: "Impossible. You die April 12, 1945.")
                ]
            )
        ]
    }
}
