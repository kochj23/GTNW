//
//  HistoricalCrises.swift
//  GTNW
//
//  Real historical nuclear/diplomatic crises by presidential administration
//  140+ scenarios from 1945-2025
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// Historical crisis database
struct HistoricalCrises {

    /// Get crises for specific administration (1789-2025)
    static func crisesForAdministration(_ adminID: String) -> [HistoricalCrisis] {
        // Try pre-nuclear first (1789-1945)
        let preNuclearCrises = crisesForPreNuclearAdmin(adminID)
        if !preNuclearCrises.isEmpty {
            return preNuclearCrises
        }

        // Then nuclear age (1945-2025)
        switch adminID {
        case "truman": return trumanCrises()
        case "eisenhower": return eisenhowerCrises()
        case "kennedy": return kennedyCrises()
        case "johnson": return johnsonCrises()
        case "nixon": return nixonCrises()
        case "ford": return fordCrises()
        case "carter": return carterCrises()
        case "reagan": return reaganCrises()
        case "bush_sr": return bushSrCrises()
        case "clinton": return clintonCrises()
        case "bush_jr": return bushJrCrises()
        case "obama": return obamaCrises()
        case "trump_first": return trumpFirstCrises()
        case "biden": return bidenCrises()
        case "trump_second": return trumpSecondCrises()
        default: return []
        }
    }

    // MARK: - Truman (1945-1953) - 12 crises

    static func trumanCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "truman_hiroshima_1945",
                title: "Atomic Bomb Decision - Hiroshima",
                year: 1945,
                description: "You must decide whether to use the atomic bomb on Japan. Invasion of Japan projected to cost 500,000+ American lives. Bomb will kill ~100,000 civilians instantly.",
                countries: ["Japan"],
                options: [
                    HistoricalCrisisOption(title: "Authorize atomic bombing", outcome: "Hiroshima destroyed. Japan surrenders. Nuclear age begins."),
                    HistoricalCrisisOption(title: "Conventional invasion of Japan", outcome: "Massive casualties on both sides. War extends into 1946."),
                    HistoricalCrisisOption(title: "Demonstrate bomb on unpopulated island", outcome: "Japan unimpressed. War continues."),
                    HistoricalCrisisOption(title: "Negotiate conditional surrender", outcome: "Emperor remains. Conservatives outraged.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_nagasaki_1945",
                title: "Second Atomic Bomb - Nagasaki",
                year: 1945,
                description: "3 days after Hiroshima, Japan has not surrendered. You have one more atomic bomb ready. Military advisors recommend immediate use.",
                countries: ["Japan"],
                options: [
                    HistoricalCrisisOption(title: "Authorize Nagasaki bombing", outcome: "Japan surrenders unconditionally. War ends."),
                    HistoricalCrisisOption(title: "Wait for Japanese response", outcome: "Hardliners in Japan advocate continuing war."),
                    HistoricalCrisisOption(title: "Demand unconditional surrender", outcome: "Japan stalls for time."),
                    HistoricalCrisisOption(title: "Offer terms with Emperor retained", outcome: "Japan accepts quickly.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_berlin_blockade_1948",
                title: "Berlin Blockade",
                year: 1948,
                description: "Stalin blockades West Berlin. 2 million civilians risk starvation. Military recommends armed convoy to break blockade, but this means war with USSR.",
                countries: ["USSR", "Germany"],
                options: [
                    HistoricalCrisisOption(title: "Berlin Airlift - supply city by air", outcome: "Successfully supplies Berlin for 11 months. Stalin backs down. Cold War begins."),
                    HistoricalCrisisOption(title: "Armed convoy breaks blockade", outcome: "Risk of WW3. Potential nuclear exchange."),
                    HistoricalCrisisOption(title: "Abandon West Berlin", outcome: "USSR takes West Berlin. NATO credibility destroyed."),
                    HistoricalCrisisOption(title: "Threaten nuclear retaliation", outcome: "Escalation to brink of war.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_ussr_nuke_1949",
                title: "Soviet Nuclear Test Detected",
                year: 1949,
                description: "USSR detonates first atomic bomb ('Joe-1'), years ahead of CIA predictions. American nuclear monopoly ended. Advisors urge massive military buildup.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Authorize hydrogen bomb development", outcome: "Arms race accelerates. H-bomb by 1952."),
                    HistoricalCrisisOption(title: "Propose international nuclear control", outcome: "USSR rejects. Seen as weakness."),
                    HistoricalCrisisOption(title: "Preemptive strike on Soviet facilities", outcome: "WW3 begins immediately."),
                    HistoricalCrisisOption(title: "Ignore and maintain current policy", outcome: "USSR builds arsenal unchecked.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_korea_1950",
                title: "North Korea Invades South Korea",
                year: 1950,
                description: "North Korea (backed by Stalin and Mao) invades South Korea. UN demands intervention. MacArthur requests authorization to use atomic bombs on China.",
                countries: ["North Korea", "China", "USSR"],
                options: [
                    HistoricalCrisisOption(title: "Conventional war - no atomic weapons", outcome: "3-year war. 36,000 Americans dead. Stalemate."),
                    HistoricalCrisisOption(title: "Authorize atomic bombs on China", outcome: "China devastated but USSR may retaliate. WW3 risk."),
                    HistoricalCrisisOption(title: "Avoid intervention", outcome: "South Korea falls to communism. Domino effect."),
                    HistoricalCrisisOption(title: "Threaten USSR with nukes", outcome: "Massive escalation risk.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_macarthur_1951",
                title: "MacArthur Defies Orders",
                year: 1951,
                description: "General MacArthur publicly demands nuclear attacks on China, defying your orders. He has massive public support. Do you fire America's most celebrated general?",
                countries: ["China"],
                options: [
                    HistoricalCrisisOption(title: "Fire MacArthur immediately", outcome: "Public outrage but civilian control maintained. Constitutional crisis avoided."),
                    HistoricalCrisisOption(title: "Allow MacArthur to continue", outcome: "Military undermines presidency. Dangerous precedent."),
                    HistoricalCrisisOption(title: "Authorize limited nuclear strikes", outcome: "China counter-attacks. USSR threatens intervention."),
                    HistoricalCrisisOption(title: "Negotiate MacArthur's retirement", outcome: "Compromise maintains some authority.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_korea_stalemate_1952",
                title: "Korean War Stalemate",
                year: 1952,
                description: "2 years of war, no end in sight. 25,000 Americans dead. Public wants resolution. MacArthur's replacement urges tactical nuclear weapons.",
                countries: ["North Korea", "China"],
                options: [
                    HistoricalCrisisOption(title: "Negotiate armistice at 38th parallel", outcome: "War ends. Korea divided. Seen as communist victory."),
                    HistoricalCrisisOption(title: "Tactical nukes on NK supply lines", outcome: "War escalates. China threatens full intervention."),
                    HistoricalCrisisOption(title: "Continue conventional war", outcome: "Casualties mount. 1953 armistice eventually."),
                    HistoricalCrisisOption(title: "Withdraw all forces", outcome: "South Korea falls. Massive political defeat.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_loyalty_crisis_1950",
                title: "McCarthy Red Scare",
                year: 1950,
                description: "Senator McCarthy claims State Department infiltrated by communists. Public paranoia about Soviet spies. Loyalty oaths demanded.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Implement loyalty programs", outcome: "Civil liberties damaged. Fear intensifies."),
                    HistoricalCrisisOption(title: "Denounce McCarthy publicly", outcome: "Political backlash. Seen as soft on communism."),
                    HistoricalCrisisOption(title: "Ignore McCarthy", outcome: "He gains power. Witch hunts escalate."),
                    HistoricalCrisisOption(title: "FBI investigation of claims", outcome: "Validates some fears, civil rights eroded.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_steel_strike_1952",
                title: "Steel Strike During War",
                year: 1952,
                description: "Steel workers strike threatens war production. You seize steel mills. Supreme Court may rule against you.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Maintain seizure of mills", outcome: "Court rules against you. Constitutional crisis."),
                    HistoricalCrisisOption(title: "Negotiate with unions", outcome: "Strike ends. Steel prices increase."),
                    HistoricalCrisisOption(title: "Break strike with military", outcome: "Authoritarian precedent. Public backlash."),
                    HistoricalCrisisOption(title: "Accept production halt", outcome: "War effort hampered.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_taft_hartley_1947",
                title: "Labor Strikes Threaten Economy",
                year: 1947,
                description: "Nationwide strikes by coal miners and railroad workers paralyze economy. Congress passes Taft-Hartley Act limiting union power.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Sign Taft-Hartley Act", outcome: "Unions furious. Your party splits."),
                    HistoricalCrisisOption(title: "Veto Taft-Hartley", outcome: "Congress overrides. You look weak."),
                    HistoricalCrisisOption(title: "Negotiate compromise", outcome: "Both sides unhappy. Strikes continue."),
                    HistoricalCrisisOption(title: "Federal seizure of industries", outcome: "Constitutional concerns.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_marshall_plan_1947",
                title: "Marshall Plan - Rebuild Europe",
                year: 1947,
                description: "Europe devastated. Stalin expanding influence. George Marshall proposes $13B aid program (equivalent to $170B today). Isolationists oppose.",
                countries: ["USSR", "France", "UK", "Germany"],
                options: [
                    HistoricalCrisisOption(title: "Approve full Marshall Plan", outcome: "Western Europe rebuilt. USSR contained. Massive cost."),
                    HistoricalCrisisOption(title: "Limited aid to key allies only", outcome: "Some countries fall to communism."),
                    HistoricalCrisisOption(title: "Reject Marshall Plan", outcome: "USSR dominates Europe. Cold War lost."),
                    HistoricalCrisisOption(title: "Include USSR in aid", outcome: "Stalin rejects but US looks generous.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_israel_1948",
                title: "Recognition of Israel",
                year: 1948,
                description: "Israel declares independence. Arab states invade. State Department warns recognition will anger Arab oil suppliers. Domestic Jewish voters support Israel.",
                countries: ["Israel"],
                options: [
                    HistoricalCrisisOption(title: "Recognize Israel immediately", outcome: "Arab states furious. Oil threatened. Jewish voters loyal."),
                    HistoricalCrisisOption(title: "Delay recognition", outcome: "Israel wins anyway. You look indecisive."),
                    HistoricalCrisisOption(title: "Support Arab states", outcome: "Domestic political suicide."),
                    HistoricalCrisisOption(title: "UN trusteeship proposal", outcome: "Nobody accepts. War continues.")
                ]
            )
        ]
    }

    // MARK: - Eisenhower (1953-1961) - 11 crises

    static func eisenhowerCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "ike_korea_end_1953",
                title: "End Korean War",
                year: 1953,
                description: "You inherit Korean stalemate. 36,000 Americans dead. Advisors divided: threaten nuclear weapons or accept division of Korea?",
                countries: ["North Korea", "China"],
                options: [
                    HistoricalCrisisOption(title: "Threaten China with nukes", outcome: "China backs down. Armistice signed July 1953."),
                    HistoricalCrisisOption(title: "Accept armistice at 38th parallel", outcome: "Korea divided permanently."),
                    HistoricalCrisisOption(title: "Pursue military victory", outcome: "China reinforces. War continues years."),
                    HistoricalCrisisOption(title: "Withdraw entirely", outcome: "South Korea falls. Political disaster.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_stalin_death_1953",
                title: "Stalin Dies - Power Vacuum in USSR",
                year: 1953,
                description: "Stalin dead. USSR in chaos. Beria, Malenkov, Khrushchev vie for power. CIA suggests exploiting instability. Window of vulnerability.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Covert operations to destabilize USSR", outcome: "Partially successful. USSR paranoia increases."),
                    HistoricalCrisisOption(title: "Peace overtures to new leadership", outcome: "Some thaw in relations. Arms race continues."),
                    HistoricalCrisisOption(title: "Ignore transition", outcome: "Khrushchev consolidates power by 1956."),
                    HistoricalCrisisOption(title: "Aggressive military posturing", outcome: "New Soviet leadership responds with hostility.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_rosenbergs_1953",
                title: "Rosenbergs Execution Decision",
                year: 1953,
                description: "Julius and Ethel Rosenberg convicted of passing atomic secrets to USSR. Death penalty appealed to you. Worldwide protests. Evidence questionable.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Deny clemency - execute both", outcome: "International outrage. Seen as ruthless."),
                    HistoricalCrisisOption(title: "Commute to life imprisonment", outcome: "Conservatives furious. Seen as soft."),
                    HistoricalCrisisOption(title: "Spare Ethel, execute Julius", outcome: "Compromise satisfies few."),
                    HistoricalCrisisOption(title: "Order new trial", outcome: "Legal delays. Political quagmire.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_guatemala_1954",
                title: "Guatemala Coup - Operation PBSUCCESS",
                year: 1954,
                description: "Guatemala's Arbenz expropriates United Fruit land. CIA proposes covert coup. Arbenz has popular support. Operation may be exposed.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Authorize CIA coup", outcome: "Arbenz overthrown. Military dictatorship installed. Blowback for decades."),
                    HistoricalCrisisOption(title: "Reject CIA plan", outcome: "Guatemala remains independent. United Fruit loses."),
                    HistoricalCrisisOption(title: "Public diplomatic pressure", outcome: "Arbenz stands firm. US looks weak."),
                    HistoricalCrisisOption(title: "Economic sanctions only", outcome: "Limited effect.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_suez_1956",
                title: "Suez Crisis",
                year: 1956,
                description: "UK, France, Israel invade Egypt to seize Suez Canal. USSR threatens nuclear strikes on London and Paris. Your closest allies act without consulting you.",
                countries: ["UK", "France", "Israel", "USSR"],
                options: [
                    HistoricalCrisisOption(title: "Side with allies - support invasion", outcome: "Arab world turns against US. USSR gains influence."),
                    HistoricalCrisisOption(title: "Oppose allies - demand withdrawal", outcome: "Suez crisis ends. Allies humiliated and angry."),
                    HistoricalCrisisOption(title: "Threaten USSR with retaliation", outcome: "Nuclear brinkmanship. Extremely dangerous."),
                    HistoricalCrisisOption(title: "Remain neutral", outcome: "Allies feel betrayed. Middle East chaos.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_sputnik_1957",
                title: "Sputnik Shock",
                year: 1957,
                description: "USSR launches Sputnik - first artificial satellite. America's technological supremacy questioned. Public fears Soviet nuclear missiles can now reach US.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Massive funding for space program", outcome: "NASA created. Space race begins. Enormous cost."),
                    HistoricalCrisisOption(title: "Downplay Soviet achievement", outcome: "Public panic. Democrats attack you."),
                    HistoricalCrisisOption(title: "Focus on missile defense", outcome: "Space program lags. USSR leads."),
                    HistoricalCrisisOption(title: "Propose space cooperation with USSR", outcome: "Rejected but you look reasonable.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_little_rock_1957",
                title: "Little Rock School Integration",
                year: 1957,
                description: "Arkansas Governor Faubus uses National Guard to block black students from school. Federal court orders integration. Constitutional crisis.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Send 101st Airborne to enforce", outcome: "Integration succeeds. South furious. Constitutional authority upheld."),
                    HistoricalCrisisOption(title: "Negotiate with Faubus", outcome: "He refuses. Federal authority questioned."),
                    HistoricalCrisisOption(title: "Avoid intervention", outcome: "Federal courts defied. Civil rights movement setback."),
                    HistoricalCrisisOption(title: "Propose gradual integration", outcome: "Satisfies nobody.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_taiwan_strait_1958",
                title: "Taiwan Strait Crisis",
                year: 1958,
                description: "China bombards Taiwan islands. JCS recommends nuclear strikes on Chinese artillery. Risk: USSR treaty with China may trigger WW3.",
                countries: ["China", "Taiwan", "USSR"],
                options: [
                    HistoricalCrisisOption(title: "Threaten nuclear retaliation", outcome: "China backs down but anger persists."),
                    HistoricalCrisisOption(title: "Conventional naval support", outcome: "Limited effectiveness. Crisis continues."),
                    HistoricalCrisisOption(title: "Abandon Taiwan", outcome: "China takes islands. US credibility damaged."),
                    HistoricalCrisisOption(title: "Tactical nukes on artillery", outcome: "China and USSR may launch WW3.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_u2_incident_1960",
                title: "U-2 Spy Plane Shot Down Over USSR",
                year: 1960,
                description: "Francis Gary Powers' U-2 spy plane shot down deep in USSR. You initially deny spying. Khrushchev has pilot alive and wreckage. Paris Summit imminent.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Admit spying, apologize", outcome: "Khrushchev storms out of summit. Détente dead."),
                    HistoricalCrisisOption(title: "Continue denying", outcome: "USSR presents evidence. You look dishonest."),
                    HistoricalCrisisOption(title: "Blame rogue CIA", outcome: "CIA furious. USSR still angry."),
                    HistoricalCrisisOption(title: "Demand pilot release", outcome: "Khrushchev refuses. Propaganda victory for USSR.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_cuba_castro_1959",
                title: "Castro Takes Cuba",
                year: 1959,
                description: "Fidel Castro overthrows Batista. CIA says he's not communist yet but may become so. 90 miles from Florida. Eisenhower Doctrine at stake.",
                countries: ["Cuba"],
                options: [
                    HistoricalCrisisOption(title: "Recognize Castro government", outcome: "Castro later turns to USSR. You're blamed."),
                    HistoricalCrisisOption(title: "CIA assassination attempts", outcome: "Multiple failures. Castro knows. Relations destroyed."),
                    HistoricalCrisisOption(title: "Economic embargo", outcome: "Pushes Castro toward USSR."),
                    HistoricalCrisisOption(title: "Invasion plans", outcome: "Leave problem for next president (Kennedy).")
                ]
            ),

            HistoricalCrisis(
                id: "ike_khrushchev_visit_1959",
                title: "Khrushchev Visits America",
                year: 1959,
                description: "Khrushchev wants to visit Disneyland. Security concerns. He's volatile - humiliating him risks nuclear incident. Camp David talks scheduled.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Allow full tour including Disneyland", outcome: "Khrushchev pleased. Brief thaw in relations."),
                    HistoricalCrisisOption(title: "Restrict visit for security", outcome: "Khrushchev insulted. Storms out."),
                    HistoricalCrisisOption(title: "Cancel visit entirely", outcome: "Major diplomatic incident."),
                    HistoricalCrisisOption(title: "Camp David only", outcome: "Compromise. Some progress.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_military_industrial_1961",
                title: "Military-Industrial Complex Warning",
                year: 1961,
                description: "Your farewell address. Defense contractors have immense political power. Do you warn America about the 'military-industrial complex'?",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Deliver warning publicly", outcome: "Historic speech. Defense industry furious. Prophetic."),
                    HistoricalCrisisOption(title: "Private warnings only", outcome: "No public impact. Problem grows."),
                    HistoricalCrisisOption(title: "Say nothing", outcome: "Complex grows unchecked."),
                    HistoricalCrisisOption(title: "Praise defense industry", outcome: "Eisenhower legacy less principled.")
                ]
            )
        ]
    }

    // MARK: - Kennedy (1961-1963) - 15 crises

    static func kennedyCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(
                id: "jfk_bay_of_pigs_1961",
                title: "Bay of Pigs Invasion",
                year: 1961,
                description: "CIA's invasion of Cuba ready to launch. 1,400 exiles trained. Eisenhower approved it. Intelligence says Castro unpopular - Cubans will rise up. Do you proceed?",
                countries: ["Cuba"],
                options: [
                    HistoricalCrisisOption(title: "Authorize invasion with air support", outcome: "Still fails but with US complicity. International condemnation."),
                    HistoricalCrisisOption(title: "Authorize but no air support", outcome: "Catastrophic failure. 114 killed, 1,189 captured. You're blamed."),
                    HistoricalCrisisOption(title: "Cancel operation", outcome: "Exiles furious. CIA angry. Castro remains."),
                    HistoricalCrisisOption(title: "Full US military invasion", outcome: "Success but USSR may put missiles in Cuba later.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_vienna_summit_1961",
                title: "Vienna Summit - Khrushchev Bullies",
                year: 1961,
                description: "Khrushchev bullies you at Vienna summit, sees you as weak after Bay of Pigs. Threatens war over Berlin. Says he'll bury you.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Stand firm on Berlin", outcome: "Khrushchev builds Berlin Wall. Crisis continues."),
                    HistoricalCrisisOption(title: "Threaten nuclear war", outcome: "Massive escalation. Extremely dangerous."),
                    HistoricalCrisisOption(title: "Negotiate Berlin compromise", outcome: "Seen as weakness. Wall built anyway."),
                    HistoricalCrisisOption(title: "Military buildup in Europe", outcome: "Arms race accelerates. Tensions high.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_berlin_wall_1961",
                title: "Berlin Wall Construction",
                year: 1961,
                description: "East Germany begins building wall dividing Berlin overnight. Tanks face each other at Checkpoint Charlie. Military wants to bulldoze wall. Khrushchev dares you.",
                countries: ["USSR", "Germany"],
                options: [
                    HistoricalCrisisOption(title: "Knock down wall with military", outcome: "WW3 starts immediately. Nuclear exchange likely."),
                    HistoricalCrisisOption(title: "Accept wall but protest", outcome: "Wall stands. You give 'Ich bin ein Berliner' speech."),
                    HistoricalCrisisOption(title: "Threaten nuclear retaliation", outcome: "Brinkmanship. Wall stays."),
                    HistoricalCrisisOption(title: "Ignore wall", outcome: "Seen as weakness. Eastern Bloc emboldened.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_cuban_missile_1962",
                title: "Cuban Missile Crisis - Day 1",
                year: 1962,
                description: "U-2 photos show Soviet nuclear missiles in Cuba. 90 miles from Florida. Still being assembled. Khrushchev lied to you. JCS recommends immediate air strikes.",
                countries: ["Cuba", "USSR"],
                options: [
                    HistoricalCrisisOption(title: "Naval blockade ('quarantine')", outcome: "13-day standoff. Khrushchev backs down. World at brink."),
                    HistoricalCrisisOption(title: "Air strikes on missile sites", outcome: "May not get them all. Soviet casualties. Escalation."),
                    HistoricalCrisisOption(title: "Invasion of Cuba", outcome: "USSR retaliates in Berlin or Turkey. WW3."),
                    HistoricalCrisisOption(title: "Accept missiles in Cuba", outcome: "Political suicide. US vulnerable.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_cuban_missile_peak_1962",
                title: "Cuban Missile Crisis - Day 13",
                year: 1962,
                description: "Soviet ship approaches quarantine line. Your orders: fire if they don't stop. Khrushchev hasn't responded to your offer. World holds breath.",
                countries: ["Cuba", "USSR"],
                options: [
                    HistoricalCrisisOption(title: "Secret deal: missiles out, no Cuba invasion", outcome: "Crisis ends. Secret Turkey missile removal. You're hero."),
                    HistoricalCrisisOption(title: "Fire on Soviet ship", outcome: "Escalation to nuclear war begins."),
                    HistoricalCrisisOption(title: "Let ship through", outcome: "Blockade fails. Khrushchev wins."),
                    HistoricalCrisisOption(title: "Ultimatum: 24 hours or invasion", outcome: "Extremely dangerous. May work.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_birmingham_1963",
                title: "Birmingham - Bull Connor's Dogs",
                year: 1963,
                description: "Bull Connor orders police dogs and fire hoses on peaceful protesters. Images shock world. King writes from jail. South threatens secession if you intervene.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Send federal troops", outcome: "Integration forced. South furious. 1964 Civil Rights Act possible."),
                    HistoricalCrisisOption(title: "Negotiate with Wallace", outcome: "He refuses. Crisis continues."),
                    HistoricalCrisisOption(title: "Stay out of 'state matter'", outcome: "Violence continues. Legacy damaged."),
                    HistoricalCrisisOption(title: "Arrest Connor on federal charges", outcome: "Constitutional crisis. Bold move.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_vietnam_advisors_1963",
                title: "Vietnam - Diem Coup",
                year: 1963,
                description: "South Vietnam's Diem is brutal dictator. Buddhist monks self-immolate. CIA says generals will coup with US blessing. Advisors divided.",
                countries: ["Vietnam"],
                options: [
                    HistoricalCrisisOption(title: "Green-light coup", outcome: "Diem assassinated. Chaos in South Vietnam. US blamed."),
                    HistoricalCrisisOption(title: "Support Diem", outcome: "Buddhists revolt. South Vietnam unstable."),
                    HistoricalCrisisOption(title: "Withdraw advisors", outcome: "South Vietnam falls to communism. Domino effect."),
                    HistoricalCrisisOption(title: "Demand Diem reforms", outcome: "He refuses. Crisis continues.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_test_ban_1963",
                title: "Nuclear Test Ban Treaty Negotiations",
                year: 1963,
                description: "Khrushchev proposes ban on atmospheric nuclear tests. Military opposes - says we need testing. Environmentalists support - radiation concerns.",
                countries: ["USSR"],
                options: [
                    HistoricalCrisisOption(title: "Sign Limited Test Ban Treaty", outcome: "Historic arms control. Underground testing continues."),
                    HistoricalCrisisOption(title: "Reject treaty", outcome: "Arms race continues unchecked. Fallout increases."),
                    HistoricalCrisisOption(title: "Demand comprehensive ban", outcome: "USSR refuses. No agreement."),
                    HistoricalCrisisOption(title: "Sign but violate secretly", outcome: "Eventually exposed. Trust destroyed.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_laos_1961",
                title: "Laos Civil War",
                year: 1961,
                description: "Communist Pathet Lao winning civil war. Thailand and South Vietnam threatened. JCS wants 60,000 troops. Eisenhower called this 'cork in bottle.'",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Send troops to Laos", outcome: "Quagmire. Diverts from Vietnam."),
                    HistoricalCrisisOption(title: "Covert support only", outcome: "Secret war. CIA expands operations."),
                    HistoricalCrisisOption(title: "Negotiate neutral Laos", outcome: "Compromise. Communists eventually win."),
                    HistoricalCrisisOption(title: "Let Laos fall", outcome: "Domino theory proven? Vietnam next.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_freedom_riders_1961",
                title: "Freedom Riders Attacked",
                year: 1961,
                description: "Integrated buses attacked in Alabama. Riders beaten, bus firebombed. Governor Patterson refuses protection. Attorney General (your brother Bobby) urges action.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Federal marshals protect riders", outcome: "Riders succeed. South angry. Civil rights progress."),
                    HistoricalCrisisOption(title: "Negotiate 'cooling off period'", outcome: "Riders refuse. You look weak."),
                    HistoricalCrisisOption(title: "No federal intervention", outcome: "Violence continues. Movement grows."),
                    HistoricalCrisisOption(title: "Arrest segregationists", outcome: "Legal battles. Bold statement.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_steel_crisis_1962",
                title: "Steel Price Crisis",
                year: 1962,
                description: "US Steel raises prices 3.5% despite your negotiated wage freeze. Inflation threatens economy. You're furious at being double-crossed.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Force price rollback (FBI, IRS pressure)", outcome: "Steel caves. Business community furious. 'Dictatorial.'"),
                    HistoricalCrisisOption(title: "Accept price increase", outcome: "Inflation rises. You look powerless."),
                    HistoricalCrisisOption(title: "Negotiate compromise", outcome: "Partial rollback. Limited success."),
                    HistoricalCrisisOption(title: "Threaten nationalization", outcome: "Extreme. Market panic.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_ole_miss_1962",
                title: "Ole Miss Integration - James Meredith",
                year: 1962,
                description: "Governor Barnett physically blocks Meredith from attending Ole Miss. Riots erupt. 2 dead. Federal marshals under siege. Mississippi in open rebellion.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Send Army to enforce integration", outcome: "Meredith enrolls. Mississippi seethes. Federal power asserted."),
                    HistoricalCrisisOption(title: "Negotiate with Barnett", outcome: "He breaks every agreement. You look foolish."),
                    HistoricalCrisisOption(title: "Back down to avoid bloodshed", outcome: "Federal courts defied. Massive precedent."),
                    HistoricalCrisisOption(title: "Arrest Barnett", outcome: "Bold but risky. Constitutional showdown.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_birmingham_church_1963",
                title: "Birmingham Church Bombing",
                year: 1963,
                description: "KKK bombs 16th Street Baptist Church. 4 little girls killed. National outrage. King demands federal action. Wallace defiant.",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "FBI manhunt, federal charges", outcome: "Some bombers caught decades later. Civil Rights Act momentum."),
                    HistoricalCrisisOption(title: "Federalize Alabama National Guard", outcome: "Direct confrontation with Wallace."),
                    HistoricalCrisisOption(title: "Propose strong Civil Rights bill", outcome: "Passes after your death (1964)."),
                    HistoricalCrisisOption(title: "States' rights approach", outcome: "Justice delayed decades.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_march_on_washington_1963",
                title: "March on Washington",
                year: 1963,
                description: "250,000 marching on Washington. King will give major speech. Conservatives fear riots. Do you publicly support or maintain distance?",
                countries: [],
                options: [
                    HistoricalCrisisOption(title: "Publicly endorse march", outcome: "Historic moment. Civil Rights Act supported. South furious."),
                    HistoricalCrisisOption(title: "Meet King privately after", outcome: "Moderate approach. Some progress."),
                    HistoricalCrisisOption(title: "Discourage march", outcome: "It happens anyway. You look tone-deaf."),
                    HistoricalCrisisOption(title: "Massive security presence", outcome: "March proceeds peacefully. 'I Have a Dream' speech.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_south_vietnam_instability_1963",
                title: "South Vietnam Government Collapse",
                year: 1963,
                description: "Diem assassinated in US-backed coup (3 weeks ago). Chaos in Saigon. Viet Cong advancing. Advisors urge major troop deployment.",
                countries: ["Vietnam"],
                options: [
                    HistoricalCrisisOption(title: "Major troop deployment (100K+)", outcome: "Full-scale war begins. (You're assassinated Nov 22, LBJ inherits)"),
                    HistoricalCrisisOption(title: "Withdraw advisors", outcome: "South Vietnam likely falls."),
                    HistoricalCrisisOption(title: "Stabilize with limited troops", outcome: "Slow escalation. Problem persists."),
                    HistoricalCrisisOption(title: "Negotiate neutrality", outcome: "Unlikely to work.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_limited_test_ban_1963",
                title: "Limited Nuclear Test Ban Treaty Finalization",
                year: 1963,
                description: "Treaty ready to sign. Bans atmospheric/space/underwater tests (underground allowed). Military fears USSR will cheat. Senate ratification uncertain.",
                countries: ["USSR", "UK"],
                options: [
                    HistoricalCrisisOption(title: "Sign treaty, push Senate ratification", outcome: "Passes 80-19. First arms control success. Legacy achievement."),
                    HistoricalCrisisOption(title: "Add verification demands", outcome: "USSR walks away. No deal."),
                    HistoricalCrisisOption(title: "Reject treaty", outcome: "Testing continues. Fallout increases. Arms race unchecked."),
                    HistoricalCrisisOption(title: "Sign but prepare to abrogate", outcome: "Cynical approach. Eventually exposed.")
                ]
            )
        ]
    }

    // Placeholder for remaining 10 presidents - To be implemented
    // Each will have 10-15 crises for complete historical coverage

    static func johnsonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "lbj_gulf_tonkin_1964", title: "Gulf of Tonkin Incident", year: 1964, description: "US destroyers report torpedo attacks by North Vietnam in international waters. McNamara urges retaliation. Intelligence unclear if attacks actually occurred.", countries: ["Vietnam", "North Korea"], options: [
                HistoricalCrisisOption(title: "Request Gulf of Tonkin Resolution", outcome: "Congress grants war powers. Vietnam War escalates massively."),
                HistoricalCrisisOption(title: "Demand investigation first", outcome: "Political pressure mounts. Eventually escalate anyway."),
                HistoricalCrisisOption(title: "Limited retaliation only", outcome: "Sends message but doesn't stop North Vietnam."),
                HistoricalCrisisOption(title: "No military response", outcome: "Seen as weakness. Hawks furious.")
            ]),
            HistoricalCrisis(id: "lbj_civil_rights_act_1964", title: "Civil Rights Act Battle", year: 1964, description: "Civil Rights Act faces Southern filibuster. You're a Southerner pushing the most comprehensive civil rights legislation ever. Party may split.", countries: [], options: [
                HistoricalCrisisOption(title: "Push Act through at all costs", outcome: "Passes. South leaves Democratic Party for generations."),
                HistoricalCrisisOption(title: "Negotiate weaker version", outcome: "Partial victory. Movement disappointed."),
                HistoricalCrisisOption(title: "Abandon legislation", outcome: "Betrays Kennedy legacy. Domestic unrest."),
                HistoricalCrisisOption(title: "Executive orders only", outcome: "Courts may overturn. Not comprehensive.")
            ]),
            HistoricalCrisis(id: "lbj_voting_rights_1965", title: "Selma and Voting Rights", year: 1965, description: "Bloody Sunday - marchers beaten on Edmund Pettus Bridge. MLK demands federal action. Wallace defiant. Nation watching.", countries: [], options: [
                HistoricalCrisisOption(title: "Federalize Alabama National Guard", outcome: "March succeeds. Voting Rights Act passes."),
                HistoricalCrisisOption(title: "Negotiate with Wallace", outcome: "He refuses. Violence continues."),
                HistoricalCrisisOption(title: "Federal troops escort marchers", outcome: "Bold move. Act passes. South furious."),
                HistoricalCrisisOption(title: "Avoid intervention", outcome: "Movement stalls. Legacy damaged.")
            ]),
            HistoricalCrisis(id: "lbj_watts_1965", title: "Watts Riots", year: 1965, description: "Los Angeles erupts after traffic stop. 34 dead, $40M damage. Riots spread to other cities. MLK's nonviolence questioned.", countries: [], options: [
                HistoricalCrisisOption(title: "Federal troops restore order", outcome: "Riots end but resentment lingers."),
                HistoricalCrisisOption(title: "Support local police only", outcome: "Riots burn for 6 days. 34 dead."),
                HistoricalCrisisOption(title: "Great Society programs accelerated", outcome: "Long-term investment. Short-term chaos."),
                HistoricalCrisisOption(title: "Law and order crackdown", outcome: "Harsh response. Future riots worse.")
            ]),
            HistoricalCrisis(id: "lbj_vietnam_escalation_1965", title: "Vietnam - 100,000 Troops Request", year: 1965, description: "Westmoreland requests 100,000 troops. McNamara supports. Ball warns of quagmire. This is the point of no return.", countries: ["Vietnam"], options: [
                HistoricalCrisisOption(title: "Approve full deployment", outcome: "500,000 troops by 1968. Quagmire confirmed."),
                HistoricalCrisisOption(title: "Limited deployment (50K)", outcome: "Half-measure fails. Eventually send more."),
                HistoricalCrisisOption(title: "Negotiate withdrawal", outcome: "South Vietnam falls. Seen as defeat."),
                HistoricalCrisisOption(title: "Bombing campaign only", outcome: "Ineffective. Ground troops needed anyway.")
            ]),
            HistoricalCrisis(id: "lbj_six_day_war_1967", title: "Six-Day War", year: 1967, description: "Israel launches preemptive strike on Egypt, Syria, Jordan. Captures Sinai, Golan Heights, West Bank, Jerusalem. USSR threatens intervention.", countries: ["Israel", "Egypt", "Syria", "USSR"], options: [
                HistoricalCrisisOption(title: "Support Israel fully", outcome: "Arab world turns against US. Oil threatened."),
                HistoricalCrisisOption(title: "Demand Israeli withdrawal", outcome: "Israel ignores. Relations strained."),
                HistoricalCrisisOption(title: "Negotiate ceasefire", outcome: "War ends. Territories remain disputed."),
                HistoricalCrisisOption(title: "Threaten USSR if intervenes", outcome: "Brinkmanship. Crisis ends quickly.")
            ]),
            HistoricalCrisis(id: "lbj_detroit_1967", title: "Detroit Riots", year: 1967, description: "Detroit erupts - worst riot in US history. 43 dead, 7,000 arrested. City burning. Governor requests federal troops.", countries: [], options: [
                HistoricalCrisisOption(title: "Send 82nd Airborne", outcome: "Order restored. Military occupation of city."),
                HistoricalCrisisOption(title: "State police handle it", outcome: "Violence spreads. Death toll rises."),
                HistoricalCrisisOption(title: "Negotiate with community", outcome: "Seen as weakness during violence."),
                HistoricalCrisisOption(title: "Martial law", outcome: "Heavy-handed. Constitutional concerns.")
            ]),
            HistoricalCrisis(id: "lbj_pueblo_1968", title: "USS Pueblo Seized by North Korea", year: 1968, description: "North Korea seizes USS Pueblo spy ship. 83 crew held hostage, tortured. JCS recommends military action. Risk: Escalation while Vietnam ongoing.", countries: ["North Korea"], options: [
                HistoricalCrisisOption(title: "Military rescue mission", outcome: "May fail. Crew killed. War with NK."),
                HistoricalCrisisOption(title: "Negotiate crew release", outcome: "Takes 11 months. Seen as weak."),
                HistoricalCrisisOption(title: "Strike NK facilities", outcome: "Crew executed. War starts."),
                HistoricalCrisisOption(title: "Apologize for 'spying'", outcome: "Humiliating but crew released.")
            ]),
            HistoricalCrisis(id: "lbj_tet_offensive_1968", title: "Tet Offensive", year: 1968, description: "Massive coordinated North Vietnamese attack across South. US Embassy besieged. Westmoreland claims 'light at end of tunnel' proven false. Public loses faith.", countries: ["Vietnam"], options: [
                HistoricalCrisisOption(title: "Massive escalation - 200K more troops", outcome: "Westmoreland request denied. You don't run for reelection."),
                HistoricalCrisisOption(title: "Bombing halt and negotiations", outcome: "Paris peace talks begin. War drags on."),
                HistoricalCrisisOption(title: "Nuclear weapons consideration", outcome: "Advisors reject. Political suicide."),
                HistoricalCrisisOption(title: "Vietnamization - turn war over to South", outcome: "Begin gradual withdrawal. Nixon inherits.")
            ]),
            HistoricalCrisis(id: "lbj_mlk_assassination_1968", title: "Martin Luther King Jr. Assassinated", year: 1968, description: "MLK shot in Memphis. 125 cities erupt in riots. 43 dead. Nation in shock. You address nation tonight.", countries: [], options: [
                HistoricalCrisisOption(title: "Deploy troops to all major cities", outcome: "Order restored. Occupation of America."),
                HistoricalCrisisOption(title: "Call for calm and unity", outcome: "Limited effect. Riots continue 6 days."),
                HistoricalCrisisOption(title: "Fast-track Fair Housing Act", outcome: "Passes as memorial. Some progress."),
                HistoricalCrisisOption(title: "Blame extremists on both sides", outcome: "Seen as tone-deaf. Anger intensifies.")
            ]),
            HistoricalCrisis(id: "lbj_rfk_assassination_1968", title: "Robert Kennedy Assassinated", year: 1968, description: "RFK shot after winning California primary. Nation devastated - second Kennedy assassination. MLK killed 2 months ago. Country unraveling.", countries: [], options: [
                HistoricalCrisisOption(title: "Call for gun control legislation", outcome: "Gun Control Act passes. NRA opposes."),
                HistoricalCrisisOption(title: "National day of mourning", outcome: "Unity moment but temporary."),
                HistoricalCrisisOption(title: "Security for all candidates", outcome: "Secret Service protection expanded."),
                HistoricalCrisisOption(title: "Address violence in America", outcome: "Speech remembered. Little immediate change.")
            ]),
            HistoricalCrisis(id: "lbj_chicago_dnc_1968", title: "Chicago Democratic Convention Riots", year: 1968, description: "Police beat protesters outside convention. TV cameras broadcast violence. Your party nominates Humphrey. Convention descends into chaos.", countries: [], options: [
                HistoricalCrisisOption(title: "Order restraint by Chicago police", outcome: "Too late. Damage done. Nixon wins."),
                HistoricalCrisisOption(title: "Support Mayor Daley's tactics", outcome: "Party split. Youth alienated."),
                HistoricalCrisisOption(title: "Move convention elsewhere", outcome: "Logistically impossible now."),
                HistoricalCrisisOption(title: "Negotiate with protesters", outcome: "Seen as weakness. Convention chaos anyway.")
            ])
        ]
    }

    static func nixonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "nixon_cambodia_1970", title: "Cambodia Invasion", year: 1970, description: "Secret bombing of Cambodia inadequate. Kissinger recommends ground invasion. Will escalate war and enrage antiwar movement.", countries: ["Cambodia", "Vietnam"], options: [
                HistoricalCrisisOption(title: "Invade Cambodia", outcome: "Protests explode nationwide. Kent State happens. War widens."),
                HistoricalCrisisOption(title: "Continue bombing only", outcome: "Less effective. Cambodia suffers."),
                HistoricalCrisisOption(title: "Negotiate Cambodian neutrality", outcome: "Communists reject. War spreads anyway."),
                HistoricalCrisisOption(title: "Withdraw from region", outcome: "South Vietnam isolated. Domino effect.")
            ]),
            HistoricalCrisis(id: "nixon_kent_state_1970", title: "Kent State Massacre", year: 1970, description: "Ohio National Guard opens fire on student protesters. 4 dead, 9 wounded. Nation shocked. Your Cambodia invasion triggered this. 450 universities close in protest.", countries: [], options: [
                HistoricalCrisisOption(title: "Federal investigation of Guard", outcome: "Some accountability. Protests continue."),
                HistoricalCrisisOption(title: "Blame protesters", outcome: "Hardens divisions. You're quote: 'bums.'"),
                HistoricalCrisisOption(title: "Meet with student leaders", outcome: "Awkward encounter. Limited effect."),
                HistoricalCrisisOption(title: "Call for national healing", outcome: "Protests eventually subside.")
            ]),
            HistoricalCrisis(id: "nixon_pentagon_papers_1971", title: "Pentagon Papers Leak", year: 1971, description: "Daniel Ellsberg leaks classified Vietnam history to NY Times. Reveals government lies. You want prosecution. First Amendment at stake.", countries: [], options: [
                HistoricalCrisisOption(title: "Prosecute Ellsberg and newspapers", outcome: "Supreme Court rules against you. Watergate mentality begins."),
                HistoricalCrisisOption(title: "Ignore leaks", outcome: "Seen as weak. But no precedent set."),
                HistoricalCrisisOption(title: "Declassify documents", outcome: "Transparency wins but Vietnam policy exposed as failed."),
                HistoricalCrisisOption(title: "Plumbers unit to stop leaks", outcome: "Leads directly to Watergate break-in.")
            ]),
            HistoricalCrisis(id: "nixon_china_opening_1972", title: "Nixon to China", year: 1972, description: "Historic opportunity to visit communist China, exploit Sino-Soviet split. Conservatives will call you traitor. Mao awaits.", countries: ["China", "USSR"], options: [
                    HistoricalCrisisOption(title: "Visit China, meet Mao", outcome: "Historic breakthrough. China-US relations normalized. USSR isolated."),
                HistoricalCrisisOption(title: "Demand concessions first", outcome: "China offended. Opportunity lost."),
                HistoricalCrisisOption(title: "Refuse - maintain Taiwan ties", outcome: "Taiwan happy. China hostile for decades."),
                HistoricalCrisisOption(title: "Secret diplomacy only", outcome: "Limited progress. No public impact.")
            ]),
            HistoricalCrisis(id: "nixon_watergate_break_in_1972", title: "Watergate Break-In Discovered", year: 1972, description: "Plumbers caught breaking into DNC headquarters. Your campaign involved. Cover-up or come clean? Election in 4 months.", countries: [], options: [
                HistoricalCrisisOption(title: "Full cover-up", outcome: "Works until 1973. Then destroys presidency."),
                HistoricalCrisisOption(title: "Cooperate fully with investigation", outcome: "Scandal ends. Reputation damaged but survive."),
                HistoricalCrisisOption(title: "Blame rogue operatives", outcome: "Partially works. Investigation continues."),
                HistoricalCrisisOption(title: "Fire everyone involved", outcome: "Looks guilty. Doesn't stop investigation.")
            ]),
            HistoricalCrisis(id: "nixon_yom_kippur_1973", title: "Yom Kippur War & Nuclear Alert", year: 1973, description: "Egypt and Syria surprise attack Israel on holiest day. Israel losing. Requests emergency aid. USSR threatens intervention. You order DEFCON 3 - highest alert since Cuban Missile Crisis.", countries: ["Israel", "Egypt", "Syria", "USSR"], options: [
                HistoricalCrisisOption(title: "Massive airlift to Israel", outcome: "Israel wins. Arab oil embargo follows. Gas crisis."),
                HistoricalCrisisOption(title: "Stay neutral", outcome: "Israel may fall. USSR gains Middle East."),
                HistoricalCrisisOption(title: "Force ceasefire immediately", outcome: "Israel trapped. Arab states emboldened."),
                HistoricalCrisisOption(title: "Threaten USSR with nuclear war", outcome: "Extremely dangerous. Crisis escalates.")
            ]),
            HistoricalCrisis(id: "nixon_saturday_massacre_1973", title: "Saturday Night Massacre", year: 1973, description: "Special Prosecutor Cox demands your tapes. You order AG Richardson to fire him. Richardson refuses and resigns. Deputy Ruckelshaus also refuses, resigns. Solicitor General Bork finally fires Cox. Constitutional crisis.", countries: [], options: [
                    HistoricalCrisisOption(title: "Fire Cox, Richardson, Ruckelshaus", outcome: "Public outrage. Impeachment proceedings begin."),
                HistoricalCrisisOption(title: "Comply with subpoena", outcome: "Tapes reveal guilt. Forced to resign."),
                HistoricalCrisisOption(title: "Claim executive privilege", outcome: "Courts rule against you. Must release tapes."),
                HistoricalCrisisOption(title: "Destroy tapes", outcome: "Obstruction of justice. Immediate impeachment.")
            ]),
            HistoricalCrisis(id: "nixon_spiro_agnew_1973", title: "Vice President Agnew Resigns", year: 1973, description: "VP Spiro Agnew caught taking bribes. Pleads no contest. Must resign. You're under Watergate investigation. Need credible replacement. Ford or Rockefeller?", countries: [], options: [
                HistoricalCrisisOption(title: "Nominate Gerald Ford", outcome: "Congress approves. Ford pardons you next year."),
                HistoricalCrisisOption(title: "Nominate Rockefeller", outcome: "Liberal Republicans happy. Conservatives furious."),
                HistoricalCrisisOption(title: "Nominate Connally", outcome: "Controversial. Confirmation difficult."),
                HistoricalCrisisOption(title: "Delay nomination", outcome: "Leadership vacuum. Crisis deepens.")
            ]),
            HistoricalCrisis(id: "nixon_opec_embargo_1973", title: "OPEC Oil Embargo", year: 1973, description: "Arab states embargo oil over your Israel support. Gas prices quadruple. Lines at pumps. Inflation soars. Economy in crisis.", countries: ["Saudi Arabia"], options: [
                HistoricalCrisisOption(title: "Rationing and price controls", outcome: "Shortages worsen. Black market emerges."),
                HistoricalCrisisOption(title: "Strategic Petroleum Reserve", outcome: "Long-term solution. Short-term pain."),
                HistoricalCrisisOption(title: "Threaten military action", outcome: "Arab states unite against US."),
                HistoricalCrisisOption(title: "Negotiate with Saudis", outcome: "Embargo ends 1974. Damage done.")
            ]),
            HistoricalCrisis(id: "nixon_tapes_decision_1974", title: "Supreme Court Orders Tapes Release", year: 1974, description: "US v. Nixon - Supreme Court unanimously orders release of tapes. Smoking gun tape proves you ordered cover-up. Resign or face certain impeachment?", countries: [], options: [
                HistoricalCrisisOption(title: "Resign immediately", outcome: "First president to resign. Ford pardons you."),
                HistoricalCrisisOption(title: "Fight impeachment", outcome: "Senate will convict. Removed from office."),
                HistoricalCrisisOption(title: "Destroy tapes and refuse", outcome: "Military may remove you. Constitutional crisis."),
                HistoricalCrisisOption(title: "Release edited transcripts only", outcome: "Courts reject. Must resign.")
            ])
        ]
    }

    static func fordCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "ford_nixon_pardon_1974", title: "Nixon Pardon Decision", year: 1974, description: "Nixon resigned. Prosecutors preparing charges. Pardon him and end 'national nightmare' or let justice proceed? Your presidency hangs on this.", countries: [], options: [
                HistoricalCrisisOption(title: "Full pardon immediately", outcome: "Approval drops 20 points. Nation outraged. Healing begins."),
                HistoricalCrisisOption(title: "Conditional pardon with admission", outcome: "Nixon refuses. Prosecution proceeds."),
                HistoricalCrisisOption(title: "Let justice proceed", outcome: "Years of trials. Nation never moves on."),
                HistoricalCrisisOption(title: "Delay decision", outcome: "Indecisive. Worse political outcome.")
            ]),
            HistoricalCrisis(id: "ford_saigon_fall_1975", title: "Fall of Saigon", year: 1975, description: "North Vietnam overruns South. Saigon surrounded. Embassy evacuation chaotic. Helicopters on rooftops. Last Americans and some South Vietnamese fleeing. 58,000 Americans died for nothing?", countries: ["Vietnam"], options: [
                HistoricalCrisisOption(title: "Emergency military aid to South", outcome: "Congress refuses. South falls anyway."),
                HistoricalCrisisOption(title: "Orderly evacuation only", outcome: "Desperate scenes. Allies abandoned. Iconic defeat."),
                HistoricalCrisisOption(title: "B-52 strikes to slow North", outcome: "Too late. Saigon falls."),
                HistoricalCrisisOption(title: "Negotiate safe passage", outcome: "North agrees. Embassy evacuated. War ends.")
            ]),
            HistoricalCrisis(id: "ford_mayaguez_1975", title: "Mayaguez Incident", year: 1975, description: "Cambodia (now communist) seizes US merchant ship Mayaguez. 40 crew hostages. Ford desperate to show strength after Vietnam. Marines ready.", countries: ["Cambodia"], options: [
                HistoricalCrisisOption(title: "Marines assault island", outcome: "Crew rescued but 41 Marines dead. Cambodians already released crew."),
                HistoricalCrisisOption(title: "Negotiate release", outcome: "Takes days. Seen as weak post-Vietnam."),
                HistoricalCrisisOption(title: "Air strikes only", outcome: "Ship damaged. Crew fate uncertain."),
                HistoricalCrisisOption(title: "Diplomatic pressure via China", outcome: "Crew released peacefully.")
            ]),
            HistoricalCrisis(id: "ford_helsinki_1975", title: "Helsinki Accords", year: 1975, description: "Agreement recognizing Soviet sphere in Eastern Europe in exchange for human rights commitments. Reagan calls you weak. USSR will violate human rights anyway.", countries: ["USSR"], options: [
                HistoricalCrisisOption(title: "Sign Helsinki Accords", outcome: "Détente continues. Human rights language used against USSR later."),
                HistoricalCrisisOption(title: "Refuse to recognize Soviet sphere", outcome: "Cold War continues. No human rights leverage."),
                HistoricalCrisisOption(title: "Sign with reservations", outcome: "USSR rejects. No agreement."),
                HistoricalCrisisOption(title: "Demand USSR troop withdrawals", outcome: "Non-starter. Negotiations collapse.")
            ])
        ]
    }

    static func carterCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "carter_iran_revolution_1979", title: "Iranian Revolution - Shah Falls", year: 1979, description: "Shah of Iran (your ally) overthrown by Khomeini. US Embassy at risk. CIA advises evacuation. Shah requests asylum. Admitting him will enrage Khomeini.", countries: ["Iran"], options: [
                HistoricalCrisisOption(title: "Admit Shah for medical treatment", outcome: "Embassy seized 2 weeks later. 444-day hostage crisis begins."),
                HistoricalCrisisOption(title: "Refuse Shah entry", outcome: "Ally betrayed. But no hostage crisis."),
                HistoricalCrisisOption(title: "Evacuate embassy immediately", outcome: "Seen as retreat. Khomeini wins without hostages."),
                HistoricalCrisisOption(title: "Recognize Khomeini government", outcome: "He rejects. Anti-American revolution continues.")
            ]),
            HistoricalCrisis(id: "carter_hostages_1979", title: "Iran Hostage Crisis Begins", year: 1979, description: "Iranian students seize US Embassy. 52 Americans hostage. Khomeini supports militants. Every day they're held, you look weaker.", countries: ["Iran"], options: [
                HistoricalCrisisOption(title: "Military rescue mission", outcome: "Desert One disaster. 8 dead. Humiliating failure."),
                HistoricalCrisisOption(title: "Negotiate release", outcome: "Takes 444 days. You lose 1980 election."),
                HistoricalCrisisOption(title: "Blockade Iran", outcome: "Hostages killed. Oil prices spike."),
                HistoricalCrisisOption(title: "Strike Iranian facilities", outcome: "Hostages executed. War with Iran.")
            ]),
            HistoricalCrisis(id: "carter_soviet_afghanistan_1979", title: "Soviet Invasion of Afghanistan", year: 1979, description: "USSR invades Afghanistan. Détente dead. Brzezinski urges arms for mujahideen. This is USSR's Vietnam opportunity.", countries: ["USSR", "Afghanistan"], options: [
                HistoricalCrisisOption(title: "Arm Afghan resistance (CIA)", outcome: "USSR bleeds for 10 years. Taliban emerges later."),
                HistoricalCrisisOption(title: "Olympic boycott", outcome: "Symbolic gesture. USSR unbothered."),
                HistoricalCrisisOption(title: "SALT II treaty abandoned", outcome: "Arms control dead. Reagan wins calling you weak."),
                HistoricalCrisisOption(title: "Accept Soviet sphere", outcome: "Political suicide. Seen as weak.")
            ]),
            HistoricalCrisis(id: "carter_three_mile_island_1979", title: "Three Mile Island Meltdown", year: 1979, description: "Nuclear reactor partial meltdown in Pennsylvania. Radiation release. 140,000 evacuate. Nuclear power's future at stake. Public panic.", countries: [], options: [
                HistoricalCrisisOption(title: "Evacuate wider area", outcome: "Panic spreads. Nuclear industry devastated."),
                HistoricalCrisisOption(title: "Visit site personally", outcome: "Reassures public. Courage noted. Nuclear survives."),
                HistoricalCrisisOption(title: "Shut down all nuclear plants", outcome: "Energy crisis worsens. Coal replaces nuclear."),
                HistoricalCrisisOption(title: "Downplay danger", outcome: "Public loses trust when details emerge.")
            ])
        ]
    }

    static func reaganCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "reagan_assassination_1981", title: "Assassination Attempt", year: 1981, description: "John Hinckley shoots you outside Washington Hilton. Bullet lodges inch from heart. You joke 'I hope you're all Republicans' as doctors operate. Survive and become legend or succumb?", countries: [], options: [
                HistoricalCrisisOption(title: "Recover with grace and humor", outcome: "Approval soars to 73%. Political invincibility for years."),
                HistoricalCrisisOption(title: "Long difficult recovery", outcome: "Weakness perceived. Agenda stalls."),
                HistoricalCrisisOption(title: "Security crackdown", outcome: "Police state concerns."),
                HistoricalCrisisOption(title: "Gun control advocacy", outcome: "NRA opposes. Against your philosophy.")
            ]),
            HistoricalCrisis(id: "reagan_patco_1981", title: "Air Traffic Controllers Strike", year: 1981, description: "PATCO union strikes illegally (federal workers can't strike). 13,000 controllers walk out. Air travel paralyzed. Union expects negotiation.", countries: [], options: [
                HistoricalCrisisOption(title: "Fire all strikers", outcome: "Union broken. Sets tough precedent. Labor movement weakened for decades."),
                HistoricalCrisisOption(title: "Negotiate settlement", outcome: "Illegal strike rewarded. Bad precedent."),
                HistoricalCrisisOption(title: "Partial amnesty", outcome: "Compromise satisfies nobody."),
                HistoricalCrisisOption(title: "Military controllers", outcome: "Temporary fix. Crisis continues.")
            ]),
            HistoricalCrisis(id: "reagan_lebanon_1983", title: "Beirut Marine Barracks Bombing", year: 1983, description: "Truck bomb kills 241 Marines in Beirut. Worst day for Marines since Iwo Jima. Iranian-backed Hezbollah responsible. Retaliate or withdraw?", countries: ["Lebanon", "Iran", "Syria"], options: [
                HistoricalCrisisOption(title: "Massive retaliation against Hezbollah", outcome: "Escalates Middle East involvement. Hostages taken."),
                HistoricalCrisisOption(title: "Withdraw Marines", outcome: "Seen as retreat. Terrorism wins. But saves lives."),
                HistoricalCrisisOption(title: "Stay but reinforced", outcome: "More targets. Eventually withdraw anyway."),
                HistoricalCrisisOption(title: "Strike Iranian facilities", outcome: "War with Iran. Hostages at risk.")
            ]),
            HistoricalCrisis(id: "reagan_grenada_1983", title: "Grenada Invasion", year: 1983, description: "Marxist coup in Grenada. US medical students at risk. Perfect opportunity to show strength after Lebanon. Invade this tiny island?", countries: ["Cuba"], options: [
                HistoricalCrisisOption(title: "Operation Urgent Fury - invade", outcome: "Quick victory. Students safe. Lebanon defeat forgotten."),
                HistoricalCrisisOption(title: "Evacuate students only", outcome: "Grenada stays communist. Missed opportunity."),
                HistoricalCrisisOption(title: "Negotiate students' safety", outcome: "Works but you look timid."),
                HistoricalCrisisOption(title: "CIA coup instead", outcome: "Covert op fails. Embarrassing.")
            ]),
            HistoricalCrisis(id: "reagan_libya_1986", title: "Libya Bombing - Qaddafi Retaliation", year: 1986, description: "Libya bombs Berlin disco, kills US servicemen. Qaddafi behind it. You have bombers ready. Strike Tripoli or show restraint?", countries: ["Libya"], options: [
                HistoricalCrisisOption(title: "Operation El Dorado Canyon", outcome: "Qaddafi's compound hit. Daughter killed. He goes quiet for years."),
                HistoricalCrisisOption(title: "Sanctions only", outcome: "Qaddafi continues terrorism."),
                HistoricalCrisisOption(title: "Covert assassination", outcome: "Attempts fail. Qaddafi paranoid."),
                HistoricalCrisisOption(title: "No response", outcome: "Terrorism continues. Seen as weak.")
            ]),
            HistoricalCrisis(id: "reagan_iran_contra_1986", title: "Iran-Contra Exposed", year: 1986, description: "Secret arms-for-hostages with Iran exposed. Profits illegally funded Contras in Nicaragua. Congress explicitly banned this. North takes blame. Did you know?", countries: ["Iran", "Nicaragua"], options: [
                HistoricalCrisisOption(title: "Take responsibility", outcome: "Approval drops. But maintain credibility."),
                HistoricalCrisisOption(title: "Blame North and Poindexter", outcome: "Works. You claim ignorance. 'I don't recall.'"),
                HistoricalCrisisOption(title: "Pardon everyone involved", outcome: "Looks guilty. Legacy damaged."),
                HistoricalCrisisOption(title: "Stonewall investigation", outcome: "Constitutional crisis. Impeachment possible.")
            ]),
            HistoricalCrisis(id: "reagan_reykjavik_1986", title: "Reykjavik Summit - Zero Nukes?", year: 1986, description: "Gorbachev proposes eliminating ALL nuclear weapons. Unprecedented. But requires abandoning SDI. Deal of the century or trap?", countries: ["USSR"], options: [
                    HistoricalCrisisOption(title: "Accept zero nukes, abandon SDI", outcome: "Historic but conservatives furious. MAD ends."),
                HistoricalCrisisOption(title: "Refuse - keep SDI", outcome: "Summit fails. But INF Treaty comes next year."),
                HistoricalCrisisOption(title: "Counter-offer: 50% reduction", outcome: "Compromise. Neither side fully satisfied."),
                HistoricalCrisisOption(title: "Demand verification first", outcome: "USSR refuses. No deal.")
            ]),
            HistoricalCrisis(id: "reagan_inf_treaty_1987", title: "INF Treaty - Eliminate Entire Weapons Class", year: 1987, description: "First treaty to eliminate entire class of nuclear weapons (intermediate-range). Gorbachev serious about reform. Conservatives say trust but verify. Sign?", countries: ["USSR"], options: [
                HistoricalCrisisOption(title: "Sign INF Treaty", outcome: "Historic arms control. Cold War winding down. Verification works."),
                HistoricalCrisisOption(title: "Demand more concessions", outcome: "Gorbachev walks away. Opportunity lost."),
                HistoricalCrisisOption(title: "Refuse - USSR untrustworthy", outcome: "Cold War continues. Gorbachev weakened."),
                HistoricalCrisisOption(title: "Sign but prepare to withdraw", outcome: "Cynical. Trust undermined.")
            ])
        ]
    }

    static func bushSrCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "bush_panama_1989", title: "Panama Invasion - Noriega", year: 1989, description: "Manuel Noriega (former CIA asset) declared dictator, involved in drugs. Killed US serviceman. 20,000 troops ready to invade.", countries: ["Panama"], options: [
                HistoricalCrisisOption(title: "Operation Just Cause - invade", outcome: "Noriega captured. Democracy restored. Quick victory."),
                HistoricalCrisisOption(title: "CIA coup attempt", outcome: "Fails. Noriega aware. Kills more Americans."),
                HistoricalCrisisOption(title: "Economic sanctions", outcome: "Ineffective. Noriega remains."),
                HistoricalCrisisOption(title: "Accept Noriega rule", outcome: "Drugs flow. Dictator 90 miles away.")
            ]),
            HistoricalCrisis(id: "bush_tiananmen_1989", title: "Tiananmen Square Massacre", year: 1989, description: "China massacres protesters in Beijing. World horrified. Congress demands sanctions. But you need China relationship. How tough to get?", countries: ["China"], options: [
                HistoricalCrisisOption(title: "Severe sanctions on China", outcome: "Relationship damaged for years. China isolated."),
                HistoricalCrisisOption(title: "Symbolic sanctions only", outcome: "Business continues. Seen as weak on human rights."),
                HistoricalCrisisOption(title: "Private diplomacy", outcome: "Relationship maintained. Critics call you complicit."),
                HistoricalCrisisOption(title: "Break relations entirely", outcome: "China turns to USSR. Strategic disaster.")
            ]),
            HistoricalCrisis(id: "bush_berlin_wall_1989", title: "Berlin Wall Falls", year: 1989, description: "Berlin Wall opened. East Germans flooding West. Gorbachev won't intervene. German reunification possible. Conservative allies fear strong Germany.", countries: ["Germany", "USSR"], options: [
                HistoricalCrisisOption(title: "Support rapid reunification", outcome: "Germany reunites 1990. New European power."),
                HistoricalCrisisOption(title: "Slow reunification process", outcome: "Thatcher, Mitterrand relieved. Germans frustrated."),
                HistoricalCrisisOption(title: "Keep Germany divided", outcome: "Impossible. Public pressure too strong."),
                HistoricalCrisisOption(title: "German NATO membership guaranteed", outcome: "Gorbachev agrees. Strengthens West.")
            ]),
            HistoricalCrisis(id: "bush_kuwait_invasion_1990", title: "Iraq Invades Kuwait", year: 1990, description: "Saddam Hussein invades Kuwait. Takes oil fields. Saudi Arabia next? You draw 'line in sand.' Half million troops ready. Congress divided.", countries: ["Iraq", "Kuwait", "Saudi Arabia"], options: [
                HistoricalCrisisOption(title: "Operation Desert Storm", outcome: "100-hour war. Decisive victory. Saddam weakened but survives."),
                HistoricalCrisisOption(title: "Sanctions and containment", outcome: "Saddam keeps Kuwait. Emboldened."),
                HistoricalCrisisOption(title: "Assassinate Saddam", outcome: "Attempts fail. War more likely."),
                HistoricalCrisisOption(title: "Negotiate Iraqi withdrawal", outcome: "Saddam refuses. Must use force.")
            ]),
            HistoricalCrisis(id: "bush_ussr_collapse_1991", title: "Soviet Union Collapses", year: 1991, description: "USSR dissolving. Gorbachev losing control. Yeltsin rises. 27,000 nuclear weapons in chaos. Who controls them? Ukraine, Kazakhstan have nukes on soil.", countries: ["USSR", "Russia", "Ukraine"], options: [
                HistoricalCrisisOption(title: "Negotiate denuclearization of former Soviet states", outcome: "Ukraine, Kazakhstan give up nukes. Russia sole successor."),
                HistoricalCrisisOption(title: "Recognize all nuclear states", outcome: "15 nuclear powers. Proliferation nightmare."),
                HistoricalCrisisOption(title: "Support Gorbachev against collapse", outcome: "Too late. Collapse inevitable."),
                HistoricalCrisisOption(title: "Seize moment - push NATO expansion", outcome: "Russia feels threatened. Future conflict seeds.")
            ])
        ]
    }

    static func clintonCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "clinton_mogadishu_1993", title: "Battle of Mogadishu - Black Hawk Down", year: 1993, description: "Somalia mission goes wrong. 18 Rangers dead. Bodies dragged through streets on TV. Public outraged. Continue mission or withdraw?", countries: ["Somalia"], options: [
                HistoricalCrisisOption(title: "Withdraw immediately", outcome: "Mission ends. Seen as retreat after casualties. Bin Laden emboldened."),
                HistoricalCrisisOption(title: "Reinforcements and continue", outcome: "Mission creep. More casualties. Eventually withdraw."),
                HistoricalCrisisOption(title: "Strike Aidid compound", outcome: "Civilian casualties. International condemnation."),
                HistoricalCrisisOption(title: "UN takes over mission", outcome: "US role reduced. Mission fails anyway.")
            ]),
            HistoricalCrisis(id: "clinton_rwanda_1994", title: "Rwanda Genocide", year: 1994, description: "800,000 Tutsis being massacred in Rwanda. UN Commander Dallaire begs for 5,000 troops to stop genocide. Post-Somalia, you're cautious. Intervene?", countries: [], options: [
                HistoricalCrisisOption(title: "Send troops immediately", outcome: "Genocide stopped. Hundreds of thousands saved."),
                HistoricalCrisisOption(title: "No intervention", outcome: "800,000 dead. 'Never Again' proven hollow."),
                HistoricalCrisisOption(title: "UN peacekeepers only", outcome: "Too few. Genocide continues."),
                HistoricalCrisisOption(title: "Jam radio broadcasts", outcome: "Minimal impact. Slaughter continues.")
            ]),
            HistoricalCrisis(id: "clinton_bosnia_1995", title: "Srebrenica Massacre & Bosnia", year: 1995, description: "Serbs massacre 8,000 Bosnian Muslims in Srebrenica. Worst atrocity in Europe since WW2. NATO bombing recommended. Russia backs Serbs.", countries: ["Serbia"], options: [
                HistoricalCrisisOption(title: "NATO air campaign", outcome: "Serbs forced to negotiate. Dayton Accords end war."),
                HistoricalCrisisOption(title: "Ground troops invasion", outcome: "Effective but casualties. Russia angry."),
                HistoricalCrisisOption(title: "Sanctions only", outcome: "Serbs continue ethnic cleansing."),
                HistoricalCrisisOption(title: "UN peacekeepers", outcome: "Ineffective. Hostages taken.")
            ]),
            HistoricalCrisis(id: "clinton_lewinsky_1998", title: "Monica Lewinsky Scandal", year: 1998, description: "Affair with intern exposed. You lied under oath. Starr Report released. Impeachment certain. Resign or fight?", countries: [], options: [
                HistoricalCrisisOption(title: "Fight impeachment", outcome: "Acquitted by Senate. Finish term. Legacy damaged."),
                HistoricalCrisisOption(title: "Resign", outcome: "Gore becomes president. Your legacy: scandal."),
                    HistoricalCrisisOption(title: "Admit affair, apologize", outcome: "Humanizes you. Republicans still impeach."),
                HistoricalCrisisOption(title: "Stonewall entirely", outcome: "Makes it worse. Impeachment certain.")
            ]),
            HistoricalCrisis(id: "clinton_kosovo_1999", title: "Kosovo War", year: 1999, description: "Serbia's Milosevic ethnically cleansing Kosovo Albanians. NATO wants to bomb. No UN authorization (Russia will veto). Illegal war to stop genocide?", countries: ["Serbia"], options: [
                HistoricalCrisisOption(title: "NATO bombing without UN approval", outcome: "78-day campaign. Serbia surrenders. Kosovo independent. Precedent set."),
                HistoricalCrisisOption(title: "Seek UN authorization", outcome: "Russia vetoes. Genocide continues."),
                HistoricalCrisisOption(title: "Ground invasion", outcome: "Effective but NATO casualties."),
                HistoricalCrisisOption(title: "No intervention", outcome: "Ethnic cleansing succeeds.")
            ])
        ]
    }

    static func bushJrCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "bush_911_2001", title: "9/11 Attacks", year: 2001, description: "Al-Qaeda hijacks 4 planes. Twin Towers collapse. Pentagon hit. 2,977 dead. Nation demands response. This will define your presidency.", countries: ["Afghanistan"], options: [
                    HistoricalCrisisOption(title: "Invade Afghanistan, topple Taliban", outcome: "Taliban falls in weeks. 20-year war follows."),
                HistoricalCrisisOption(title: "Special Forces + airstrikes only", outcome: "Effective. No nation-building quagmire."),
                HistoricalCrisisOption(title: "Negotiations with Taliban", outcome: "They refuse to hand over Bin Laden."),
                HistoricalCrisisOption(title: "Strike Al-Qaeda camps only", outcome: "Bin Laden escapes. Problem persists.")
            ]),
            HistoricalCrisis(id: "bush_axis_evil_2002", title: "Axis of Evil Speech", year: 2002, description: "You label Iraq, Iran, North Korea 'axis of evil.' Neocons want regime change in all three. Critics say this guarantees their nuclear programs.", countries: ["Iraq", "Iran", "North Korea"], options: [
                HistoricalCrisisOption(title: "Pursue regime change in all three", outcome: "Massive overreach. Iraq invasion follows."),
                HistoricalCrisisOption(title: "Focus on Iraq only", outcome: "Iran and NK accelerate nuclear programs."),
                HistoricalCrisisOption(title: "Diplomacy instead of threats", outcome: "Seen as backing down. Neocons furious."),
                    HistoricalCrisisOption(title: "Military pressure, no invasion", outcome: "Containment strategy. Avoids war.")
            ]),
            HistoricalCrisis(id: "bush_iraq_wmd_2003", title: "Iraq WMD Intelligence", year: 2003, description: "CIA says Iraq has WMD (confidence: moderate). UN inspectors find nothing. Cheney certain. Powell skeptical. Invade or not?", countries: ["Iraq"], options: [
                HistoricalCrisisOption(title: "Invade Iraq", outcome: "Saddam toppled. No WMD found. 8-year war. Trillions spent."),
                HistoricalCrisisOption(title: "Give inspectors more time", outcome: "No WMD found. No war. Iran regional power."),
                HistoricalCrisisOption(title: "Containment and sanctions", outcome: "Saddam weakened but survives."),
                HistoricalCrisisOption(title: "CIA coup attempt", outcome: "Fails. War more likely.")
            ]),
            HistoricalCrisis(id: "bush_katrina_2005", title: "Hurricane Katrina", year: 2005, description: "Category 5 hurricane devastates New Orleans. Levees fail. Thousands stranded. Bodies floating. FEMA director: 'doing a heck of a job.' Response inadequate. City abandoned?", countries: [], options: [
                HistoricalCrisisOption(title: "Massive federal response immediately", outcome: "Lives saved. Still 1,800 dead. Government competent."),
                HistoricalCrisisOption(title: "Let state handle it", outcome: "Chaos. 1,800 dead. 'Brownie' fired. Approval craters."),
                HistoricalCrisisOption(title: "Military takes over", outcome: "Effective but controversial federalization."),
                HistoricalCrisisOption(title: "Blame state/local officials", outcome: "Deflects but doesn't help victims.")
            ]),
            HistoricalCrisis(id: "bush_financial_crisis_2008", title: "Financial Crisis - TARP Decision", year: 2008, description: "Lehman Brothers collapses. Banks failing. Credit frozen. Paulson demands $700B bailout. Capitalism itself at risk. Tea Party will revolt.", countries: [], options: [
                HistoricalCrisisOption(title: "TARP bailout - $700B", outcome: "System stabilized. Massive debt. Tea Party emerges."),
                HistoricalCrisisOption(title: "Let banks fail", outcome: "Great Depression 2.0. Unemployment 25%."),
                HistoricalCrisisOption(title: "Nationalize failed banks", outcome: "Socialism. Conservatives apoplectic."),
                    HistoricalCrisisOption(title: "Bailout Main Street, not Wall Street", outcome: "Takes too long. System collapses.")
            ])
        ]
    }

    static func obamaCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "obama_bin_laden_2011", title: "Bin Laden Raid Decision", year: 2011, description: "CIA thinks Bin Laden in Pakistan compound. Confidence: 60-80%. Options: raid, bomb, or wait for more intel. Pakistan will be furious. Helicopters may crash.", countries: ["Pakistan"], options: [
                HistoricalCrisisOption(title: "Green-light SEAL Team 6 raid", outcome: "Bin Laden killed. Pakistan outraged. Political win."),
                HistoricalCrisisOption(title: "Bomb compound", outcome: "Can't confirm kill. Civilian casualties."),
                HistoricalCrisisOption(title: "Wait for more intelligence", outcome: "Bin Laden may escape. Opportunity lost."),
                HistoricalCrisisOption(title: "Inform Pakistan and coordinate", outcome: "Bin Laden tipped off. Escapes.")
            ]),
            HistoricalCrisis(id: "obama_syria_red_line_2013", title: "Syria Chemical Weapons Red Line", year: 2013, description: "Assad uses chemical weapons on civilians. You said this was 'red line.' Congress opposes intervention. Russia backs Assad. Enforce red line or not?", countries: ["Syria", "Russia"], options: [
                HistoricalCrisisOption(title: "Strikes on Assad forces", outcome: "Russia threatens response. Limited impact."),
                HistoricalCrisisOption(title: "Back down - no action", outcome: "Red line proven empty. Credibility destroyed."),
                HistoricalCrisisOption(title: "Negotiate chemical weapons removal", outcome: "Russia brokers deal. Assad gives up CW but stays."),
                HistoricalCrisisOption(title: "Arm rebels instead", outcome: "Some arms end up with ISIS.")
            ]),
            HistoricalCrisis(id: "obama_crimea_2014", title: "Russia Annexes Crimea", year: 2014, description: "Putin seizes Crimea from Ukraine. First forcible annexation in Europe since WW2. NATO alarmed. Military options limited. Sanctions or war?", countries: ["Russia", "Ukraine"], options: [
                HistoricalCrisisOption(title: "Severe sanctions on Russia", outcome: "Hurts Russian economy. Crimea stays annexed."),
                HistoricalCrisisOption(title: "Military aid to Ukraine", outcome: "Proxy war begins. Ongoing conflict."),
                HistoricalCrisisOption(title: "Accept annexation", outcome: "International law dead. Putin emboldened."),
                HistoricalCrisisOption(title: "NATO troops to Ukraine", outcome: "Direct confrontation with Russia. WW3 risk.")
            ]),
            HistoricalCrisis(id: "obama_isis_2014", title: "ISIS Rises - Intervention?", year: 2014, description: "ISIS declares caliphate, controls third of Iraq. Genocide of Yazidis. Beheading Americans on video. You promised no more Middle East wars. Break promise?", countries: ["Iraq", "Syria"], options: [
                HistoricalCrisisOption(title: "Air campaign + special forces", outcome: "ISIS eventually defeated but takes years."),
                HistoricalCrisisOption(title: "Ground troops invasion", outcome: "Effective but breaks campaign promise. Political cost."),
                HistoricalCrisisOption(title: "Arm Kurdish forces only", outcome: "ISIS contained. Turkey furious."),
                HistoricalCrisisOption(title: "No intervention", outcome: "ISIS expands. Genocide continues.")
            ]),
            HistoricalCrisis(id: "obama_iran_deal_2015", title: "Iran Nuclear Deal", year: 2015, description: "Deal will constrain Iran's nuclear program for 10-15 years. Conservatives say it's too weak. Israel vehemently opposes. Sign anyway?", countries: ["Iran", "Israel"], options: [
                HistoricalCrisisOption(title: "Sign JCPOA", outcome: "Iran's program frozen. Israel furious. Trump exits deal later."),
                HistoricalCrisisOption(title: "Demand stronger terms", outcome: "Iran walks away. Nuclear program unconstrained."),
                HistoricalCrisisOption(title: "Reject deal", outcome: "Iran continues toward bomb. Military option only."),
                HistoricalCrisisOption(title: "Sign but maintain sanctions", outcome: "Bad faith. Deal collapses.")
            ])
        ]
    }

    static func trumpFirstCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "trump_charlottesville_2017", title: "Charlottesville - Unite the Right Rally", year: 2017, description: "White supremacists march in Charlottesville. Counter-protester killed. You say 'very fine people on both sides.' Backlash. Clarify or double down?", countries: [], options: [
                HistoricalCrisisOption(title: "Clarify - condemn white supremacists", outcome: "Base unhappy but crisis contained."),
                HistoricalCrisisOption(title: "Double down on both sides", outcome: "CEOs resign from councils. Approval drops."),
                HistoricalCrisisOption(title: "Don't address it", outcome: "Silence seen as endorsement."),
                HistoricalCrisisOption(title: "Blame media", outcome: "Divisiveness continues.")
            ]),
            HistoricalCrisis(id: "trump_north_korea_2017", title: "North Korea Nuclear Crisis - Rocket Man", year: 2017, description: "Kim Jong Un testing ICBMs that can reach US. You threaten 'fire and fury.' He calls you 'dotard.' Nuclear war possible. Your move.", countries: ["North Korea"], options: [
                HistoricalCrisisOption(title: "Preemptive strike on NK", outcome: "Seoul destroyed by artillery. Millions dead. China intervenes."),
                HistoricalCrisisOption(title: "Maximum pressure sanctions", outcome: "Leads to Singapore summit. Détente but no denuclearization."),
                HistoricalCrisisOption(title: "Accept NK as nuclear power", outcome: "Proliferation precedent. Allies nervous."),
                HistoricalCrisisOption(title: "Threaten China", outcome: "China tightens NK sanctions. Some effect.")
            ]),
            HistoricalCrisis(id: "trump_covid_2020", title: "COVID-19 Pandemic", year: 2020, description: "Novel coronavirus from China spreading. Fauci recommends lockdowns. Economic devastation. Election in 8 months. Downplay or react aggressively?", countries: ["China"], options: [
                HistoricalCrisisOption(title: "National lockdown immediately", outcome: "Flattens curve. Economy craters. You lose election."),
                HistoricalCrisisOption(title: "State-led response", outcome: "Inconsistent. 400,000 dead by January. Election close."),
                HistoricalCrisisOption(title: "Downplay severity", outcome: "Stock market preserved initially. Deaths mount. Blamed."),
                HistoricalCrisisOption(title: "Operation Warp Speed vaccine", outcome: "Vaccines by December. Too late for election.")
            ]),
            HistoricalCrisis(id: "trump_jan6_2021", title: "January 6 Capitol Riot", year: 2021, description: "Your supporters storm Capitol to stop Biden certification. 5 dead. Pence in hiding. Nation watching. Call them off or let it play out?", countries: [], options: [
                HistoricalCrisisOption(title: "Video telling them to go home", outcome: "Riot ends. Second impeachment follows."),
                HistoricalCrisisOption(title: "Encourage them ('fight like hell')", outcome: "Riot intensifies. Democracy at risk. Impeached."),
                HistoricalCrisisOption(title: "Call in National Guard", outcome: "Order restored. Criticized for inciting then stopping."),
                HistoricalCrisisOption(title: "Say nothing", outcome: "Riot continues hours. Democracy damaged.")
            ])
        ]
    }

    static func bidenCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "biden_afghanistan_2021", title: "Afghanistan Withdrawal", year: 2021, description: "Afghanistan evacuations chaotic. Kabul airport suicide bombing kills 13 Marines. Taliban taking over. Equipment abandoned. Allies stranded. Finish evacuation or extend deadline?", countries: ["Afghanistan"], options: [
                    HistoricalCrisisOption(title: "Extend deadline, evacuate all allies", outcome: "Taliban refuses. Negotiations difficult."),
                HistoricalCrisisOption(title: "Stick to Aug 31 deadline", outcome: "Chaotic exit. Allies abandoned. Approval craters."),
                HistoricalCrisisOption(title: "Resume military operations", outcome: "20-year war continues. Taliban still wins."),
                HistoricalCrisisOption(title: "Negotiate Taliban government share", outcome: "Taliban uninterested. Take full control.")
            ]),
            HistoricalCrisis(id: "biden_ukraine_invasion_2022", title: "Russia Invades Ukraine", year: 2022, description: "Putin launches full-scale invasion. Kyiv under siege. Zelensky requests no-fly zone. Your move could trigger WW3 or embolden Putin.", countries: ["Russia", "Ukraine"], options: [
                HistoricalCrisisOption(title: "Massive military aid to Ukraine", outcome: "Ukraine fights back. War ongoing. Russia weakened."),
                HistoricalCrisisOption(title: "NATO enforces no-fly zone", outcome: "Shoots down Russian planes. Direct NATO-Russia war."),
                HistoricalCrisisOption(title: "Limited sanctions only", outcome: "Insufficient. Ukraine falls. NATO credibility dead."),
                HistoricalCrisisOption(title: "Negotiate Ukraine neutrality", outcome: "Zelensky refuses. Ukraine fights anyway.")
            ]),
            HistoricalCrisis(id: "biden_israel_gaza_2023", title: "Hamas October 7 Attack & Gaza War", year: 2023, description: "Hamas massacres 1,200 Israelis. Israel vows to eliminate Hamas. Gaza campaign kills 30,000+. Ceasefire pressure vs Israel support.", countries: ["Israel"], options: [
                HistoricalCrisisOption(title: "Full support for Israel", outcome: "Arab world furious. Protests nationwide. War continues."),
                HistoricalCrisisOption(title: "Demand immediate ceasefire", outcome: "Israel ignores. Hamas undefeated."),
                HistoricalCrisisOption(title: "Condition aid on civilian protection", outcome: "Difficult enforcement. Some moderation."),
                HistoricalCrisisOption(title: "Withdraw support", outcome: "Domestic political suicide. Israel isolated.")
            ])
        ]
    }

    static func trumpSecondCrises() -> [HistoricalCrisis] {
        return [
            HistoricalCrisis(id: "trump2_taiwan_2025", title: "China-Taiwan Crisis", year: 2025, description: "China blockades Taiwan. You said 'Taiwan must pay for defense.' Xi tests your resolve. Defend Taiwan or not?", countries: ["China", "Taiwan"], options: [
                HistoricalCrisisOption(title: "Naval forces break blockade", outcome: "Direct US-China military confrontation. Nuclear powers clash."),
                HistoricalCrisisOption(title: "Negotiate Taiwan independence", outcome: "China refuses. Blockade continues."),
                HistoricalCrisisOption(title: "Accept Chinese reunification", outcome: "Taiwan annexed. US credibility destroyed."),
                HistoricalCrisisOption(title: "Arm Taiwan heavily", outcome: "Proxy war. China eventually invades.")
            ]),
            HistoricalCrisis(id: "trump2_iran_nuclear_2025", title: "Iran Nuclear Breakout", year: 2025, description: "Iran enriches to weapons-grade. JCPOA long dead. Weeks from bomb. Israel demands action. Strike now or accept nuclear Iran?", countries: ["Iran", "Israel"], options: [
                HistoricalCrisisOption(title: "Military strikes on facilities", outcome: "Program delayed 5-10 years. Regional war."),
                HistoricalCrisisOption(title: "Support Israeli strike", outcome: "US complicit. Iran retaliates."),
                HistoricalCrisisOption(title: "Accept nuclear Iran", outcome: "Saudi Arabia, Turkey go nuclear. Cascade."),
                HistoricalCrisisOption(title: "Negotiate new deal", outcome: "Iran demands sanctions lifted first.")
            ])
        ]
    }

}

// MARK: - Data Model

struct HistoricalCrisis: Identifiable, Codable {
    let id: String
    let title: String
    let year: Int
    let description: String
    let countries: [String]
    let options: [HistoricalCrisisOption]

    var severityLevel: String {
        if title.contains("Nuclear") || title.contains("Missile") { return "CATASTROPHIC" }
        if title.contains("War") || title.contains("Invasion") { return "CRITICAL" }
        if title.contains("Crisis") { return "SERIOUS" }
        return "MODERATE"
    }
}

/// Simplified crisis option used by historical scenario crises.
/// Uses `outcome` instead of `consequences` for cleaner historical data entry.
struct HistoricalCrisisOption: Identifiable, Codable {
    let id: UUID
    let title: String
    let outcome: String

    init(title: String, outcome: String) {
        self.id = UUID()
        self.title = title
        self.outcome = outcome
    }

    var successChance: Double {
        // Estimate based on historical outcomes
        if outcome.contains("success") || outcome.contains("succeeds") { return 0.8 }
        if outcome.contains("fails") || outcome.contains("disaster") { return 0.3 }
        return 0.6
    }
}
