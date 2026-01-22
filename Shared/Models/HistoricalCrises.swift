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

    /// Get crises for specific administration
    static func crisesForAdministration(_ adminID: String) -> [HistoricalCrisis] {
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
                    CrisisOption(title: "Authorize atomic bombing", outcome: "Hiroshima destroyed. Japan surrenders. Nuclear age begins."),
                    CrisisOption(title: "Conventional invasion of Japan", outcome: "Massive casualties on both sides. War extends into 1946."),
                    CrisisOption(title: "Demonstrate bomb on unpopulated island", outcome: "Japan unimpressed. War continues."),
                    CrisisOption(title: "Negotiate conditional surrender", outcome: "Emperor remains. Conservatives outraged.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_nagasaki_1945",
                title: "Second Atomic Bomb - Nagasaki",
                year: 1945,
                description: "3 days after Hiroshima, Japan has not surrendered. You have one more atomic bomb ready. Military advisors recommend immediate use.",
                countries: ["Japan"],
                options: [
                    CrisisOption(title: "Authorize Nagasaki bombing", outcome: "Japan surrenders unconditionally. War ends."),
                    CrisisOption(title: "Wait for Japanese response", outcome: "Hardliners in Japan advocate continuing war."),
                    CrisisOption(title: "Demand unconditional surrender", outcome: "Japan stalls for time."),
                    CrisisOption(title: "Offer terms with Emperor retained", outcome: "Japan accepts quickly.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_berlin_blockade_1948",
                title: "Berlin Blockade",
                year: 1948,
                description: "Stalin blockades West Berlin. 2 million civilians risk starvation. Military recommends armed convoy to break blockade, but this means war with USSR.",
                countries: ["USSR", "Germany"],
                options: [
                    CrisisOption(title: "Berlin Airlift - supply city by air", outcome: "Successfully supplies Berlin for 11 months. Stalin backs down. Cold War begins."),
                    CrisisOption(title: "Armed convoy breaks blockade", outcome: "Risk of WW3. Potential nuclear exchange."),
                    CrisisOption(title: "Abandon West Berlin", outcome: "USSR takes West Berlin. NATO credibility destroyed."),
                    CrisisOption(title: "Threaten nuclear retaliation", outcome: "Escalation to brink of war.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_ussr_nuke_1949",
                title: "Soviet Nuclear Test Detected",
                year: 1949,
                description: "USSR detonates first atomic bomb ('Joe-1'), years ahead of CIA predictions. American nuclear monopoly ended. Advisors urge massive military buildup.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Authorize hydrogen bomb development", outcome: "Arms race accelerates. H-bomb by 1952."),
                    CrisisOption(title: "Propose international nuclear control", outcome: "USSR rejects. Seen as weakness."),
                    CrisisOption(title: "Preemptive strike on Soviet facilities", outcome: "WW3 begins immediately."),
                    CrisisOption(title: "Ignore and maintain current policy", outcome: "USSR builds arsenal unchecked.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_korea_1950",
                title: "North Korea Invades South Korea",
                year: 1950,
                description: "North Korea (backed by Stalin and Mao) invades South Korea. UN demands intervention. MacArthur requests authorization to use atomic bombs on China.",
                countries: ["North Korea", "China", "USSR"],
                options: [
                    CrisisOption(title: "Conventional war - no atomic weapons", outcome: "3-year war. 36,000 Americans dead. Stalemate."),
                    CrisisOption(title: "Authorize atomic bombs on China", outcome: "China devastated but USSR may retaliate. WW3 risk."),
                    CrisisOption(title: "Avoid intervention", outcome: "South Korea falls to communism. Domino effect."),
                    CrisisOption(title: "Threaten USSR with nukes", outcome: "Massive escalation risk.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_macarthur_1951",
                title: "MacArthur Defies Orders",
                year: 1951,
                description: "General MacArthur publicly demands nuclear attacks on China, defying your orders. He has massive public support. Do you fire America's most celebrated general?",
                countries: ["China"],
                options: [
                    CrisisOption(title: "Fire MacArthur immediately", outcome: "Public outrage but civilian control maintained. Constitutional crisis avoided."),
                    CrisisOption(title: "Allow MacArthur to continue", outcome: "Military undermines presidency. Dangerous precedent."),
                    CrisisOption(title: "Authorize limited nuclear strikes", outcome: "China counter-attacks. USSR threatens intervention."),
                    CrisisOption(title: "Negotiate MacArthur's retirement", outcome: "Compromise maintains some authority.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_korea_stalemate_1952",
                title: "Korean War Stalemate",
                year: 1952,
                description: "2 years of war, no end in sight. 25,000 Americans dead. Public wants resolution. MacArthur's replacement urges tactical nuclear weapons.",
                countries: ["North Korea", "China"],
                options: [
                    CrisisOption(title: "Negotiate armistice at 38th parallel", outcome: "War ends. Korea divided. Seen as communist victory."),
                    CrisisOption(title: "Tactical nukes on NK supply lines", outcome: "War escalates. China threatens full intervention."),
                    CrisisOption(title: "Continue conventional war", outcome: "Casualties mount. 1953 armistice eventually."),
                    CrisisOption(title: "Withdraw all forces", outcome: "South Korea falls. Massive political defeat.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_loyalty_crisis_1950",
                title: "McCarthy Red Scare",
                year: 1950,
                description: "Senator McCarthy claims State Department infiltrated by communists. Public paranoia about Soviet spies. Loyalty oaths demanded.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Implement loyalty programs", outcome: "Civil liberties damaged. Fear intensifies."),
                    CrisisOption(title: "Denounce McCarthy publicly", outcome: "Political backlash. Seen as soft on communism."),
                    CrisisOption(title: "Ignore McCarthy", outcome: "He gains power. Witch hunts escalate."),
                    CrisisOption(title: "FBI investigation of claims", outcome: "Validates some fears, civil rights eroded.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_steel_strike_1952",
                title: "Steel Strike During War",
                year: 1952,
                description: "Steel workers strike threatens war production. You seize steel mills. Supreme Court may rule against you.",
                countries: [],
                options: [
                    CrisisOption(title: "Maintain seizure of mills", outcome: "Court rules against you. Constitutional crisis."),
                    CrisisOption(title: "Negotiate with unions", outcome: "Strike ends. Steel prices increase."),
                    CrisisOption(title: "Break strike with military", outcome: "Authoritarian precedent. Public backlash."),
                    CrisisOption(title: "Accept production halt", outcome: "War effort hampered.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_taft_hartley_1947",
                title: "Labor Strikes Threaten Economy",
                year: 1947,
                description: "Nationwide strikes by coal miners and railroad workers paralyze economy. Congress passes Taft-Hartley Act limiting union power.",
                countries: [],
                options: [
                    CrisisOption(title: "Sign Taft-Hartley Act", outcome: "Unions furious. Your party splits."),
                    CrisisOption(title: "Veto Taft-Hartley", outcome: "Congress overrides. You look weak."),
                    CrisisOption(title: "Negotiate compromise", outcome: "Both sides unhappy. Strikes continue."),
                    CrisisOption(title: "Federal seizure of industries", outcome: "Constitutional concerns.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_marshall_plan_1947",
                title: "Marshall Plan - Rebuild Europe",
                year: 1947,
                description: "Europe devastated. Stalin expanding influence. George Marshall proposes $13B aid program (equivalent to $170B today). Isolationists oppose.",
                countries: ["USSR", "France", "UK", "Germany"],
                options: [
                    CrisisOption(title: "Approve full Marshall Plan", outcome: "Western Europe rebuilt. USSR contained. Massive cost."),
                    CrisisOption(title: "Limited aid to key allies only", outcome: "Some countries fall to communism."),
                    CrisisOption(title: "Reject Marshall Plan", outcome: "USSR dominates Europe. Cold War lost."),
                    CrisisOption(title: "Include USSR in aid", outcome: "Stalin rejects but US looks generous.")
                ]
            ),

            HistoricalCrisis(
                id: "truman_israel_1948",
                title: "Recognition of Israel",
                year: 1948,
                description: "Israel declares independence. Arab states invade. State Department warns recognition will anger Arab oil suppliers. Domestic Jewish voters support Israel.",
                countries: ["Israel"],
                options: [
                    CrisisOption(title: "Recognize Israel immediately", outcome: "Arab states furious. Oil threatened. Jewish voters loyal."),
                    CrisisOption(title: "Delay recognition", outcome: "Israel wins anyway. You look indecisive."),
                    CrisisOption(title: "Support Arab states", outcome: "Domestic political suicide."),
                    CrisisOption(title: "UN trusteeship proposal", outcome: "Nobody accepts. War continues.")
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
                    CrisisOption(title: "Threaten China with nukes", outcome: "China backs down. Armistice signed July 1953."),
                    CrisisOption(title: "Accept armistice at 38th parallel", outcome: "Korea divided permanently."),
                    CrisisOption(title: "Pursue military victory", outcome: "China reinforces. War continues years."),
                    CrisisOption(title: "Withdraw entirely", outcome: "South Korea falls. Political disaster.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_stalin_death_1953",
                title: "Stalin Dies - Power Vacuum in USSR",
                year: 1953,
                description: "Stalin dead. USSR in chaos. Beria, Malenkov, Khrushchev vie for power. CIA suggests exploiting instability. Window of vulnerability.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Covert operations to destabilize USSR", outcome: "Partially successful. USSR paranoia increases."),
                    CrisisOption(title: "Peace overtures to new leadership", outcome: "Some thaw in relations. Arms race continues."),
                    CrisisOption(title: "Ignore transition", outcome: "Khrushchev consolidates power by 1956."),
                    CrisisOption(title: "Aggressive military posturing", outcome: "New Soviet leadership responds with hostility.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_rosenbergs_1953",
                title: "Rosenbergs Execution Decision",
                year: 1953,
                description: "Julius and Ethel Rosenberg convicted of passing atomic secrets to USSR. Death penalty appealed to you. Worldwide protests. Evidence questionable.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Deny clemency - execute both", outcome: "International outrage. Seen as ruthless."),
                    CrisisOption(title: "Commute to life imprisonment", outcome: "Conservatives furious. Seen as soft."),
                    CrisisOption(title: "Spare Ethel, execute Julius", outcome: "Compromise satisfies few."),
                    CrisisOption(title: "Order new trial", outcome: "Legal delays. Political quagmire.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_guatemala_1954",
                title: "Guatemala Coup - Operation PBSUCCESS",
                year: 1954,
                description: "Guatemala's Arbenz expropriates United Fruit land. CIA proposes covert coup. Arbenz has popular support. Operation may be exposed.",
                countries: [],
                options: [
                    CrisisOption(title: "Authorize CIA coup", outcome: "Arbenz overthrown. Military dictatorship installed. Blowback for decades."),
                    CrisisOption(title: "Reject CIA plan", outcome: "Guatemala remains independent. United Fruit loses."),
                    CrisisOption(title: "Public diplomatic pressure", outcome: "Arbenz stands firm. US looks weak."),
                    CrisisOption(title: "Economic sanctions only", outcome: "Limited effect.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_suez_1956",
                title: "Suez Crisis",
                year: 1956,
                description: "UK, France, Israel invade Egypt to seize Suez Canal. USSR threatens nuclear strikes on London and Paris. Your closest allies act without consulting you.",
                countries: ["UK", "France", "Israel", "USSR"],
                options: [
                    CrisisOption(title: "Side with allies - support invasion", outcome: "Arab world turns against US. USSR gains influence."),
                    CrisisOption(title: "Oppose allies - demand withdrawal", outcome: "Suez crisis ends. Allies humiliated and angry."),
                    CrisisOption(title: "Threaten USSR with retaliation", outcome: "Nuclear brinkmanship. Extremely dangerous."),
                    CrisisOption(title: "Remain neutral", outcome: "Allies feel betrayed. Middle East chaos.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_sputnik_1957",
                title: "Sputnik Shock",
                year: 1957,
                description: "USSR launches Sputnik - first artificial satellite. America's technological supremacy questioned. Public fears Soviet nuclear missiles can now reach US.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Massive funding for space program", outcome: "NASA created. Space race begins. Enormous cost."),
                    CrisisOption(title: "Downplay Soviet achievement", outcome: "Public panic. Democrats attack you."),
                    CrisisOption(title: "Focus on missile defense", outcome: "Space program lags. USSR leads."),
                    CrisisOption(title: "Propose space cooperation with USSR", outcome: "Rejected but you look reasonable.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_little_rock_1957",
                title: "Little Rock School Integration",
                year: 1957,
                description: "Arkansas Governor Faubus uses National Guard to block black students from school. Federal court orders integration. Constitutional crisis.",
                countries: [],
                options: [
                    CrisisOption(title: "Send 101st Airborne to enforce", outcome: "Integration succeeds. South furious. Constitutional authority upheld."),
                    CrisisOption(title: "Negotiate with Faubus", outcome: "He refuses. Federal authority questioned."),
                    CrisisOption(title: "Avoid intervention", outcome: "Federal courts defied. Civil rights movement setback."),
                    CrisisOption(title: "Propose gradual integration", outcome: "Satisfies nobody.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_taiwan_strait_1958",
                title: "Taiwan Strait Crisis",
                year: 1958,
                description: "China bombards Taiwan islands. JCS recommends nuclear strikes on Chinese artillery. Risk: USSR treaty with China may trigger WW3.",
                countries: ["China", "Taiwan", "USSR"],
                options: [
                    CrisisOption(title: "Threaten nuclear retaliation", outcome: "China backs down but anger persists."),
                    CrisisOption(title: "Conventional naval support", outcome: "Limited effectiveness. Crisis continues."),
                    CrisisOption(title: "Abandon Taiwan", outcome: "China takes islands. US credibility damaged."),
                    CrisisOption(title: "Tactical nukes on artillery", outcome: "China and USSR may launch WW3.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_u2_incident_1960",
                title: "U-2 Spy Plane Shot Down Over USSR",
                year: 1960,
                description: "Francis Gary Powers' U-2 spy plane shot down deep in USSR. You initially deny spying. Khrushchev has pilot alive and wreckage. Paris Summit imminent.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Admit spying, apologize", outcome: "Khrushchev storms out of summit. Détente dead."),
                    CrisisOption(title: "Continue denying", outcome: "USSR presents evidence. You look dishonest."),
                    CrisisOption(title: "Blame rogue CIA", outcome: "CIA furious. USSR still angry."),
                    CrisisOption(title: "Demand pilot release", outcome: "Khrushchev refuses. Propaganda victory for USSR.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_cuba_castro_1959",
                title: "Castro Takes Cuba",
                year: 1959,
                description: "Fidel Castro overthrows Batista. CIA says he's not communist yet but may become so. 90 miles from Florida. Eisenhower Doctrine at stake.",
                countries: ["Cuba"],
                options: [
                    CrisisOption(title: "Recognize Castro government", outcome: "Castro later turns to USSR. You're blamed."),
                    CrisisOption(title: "CIA assassination attempts", outcome: "Multiple failures. Castro knows. Relations destroyed."),
                    CrisisOption(title: "Economic embargo", outcome: "Pushes Castro toward USSR."),
                    CrisisOption(title: "Invasion plans", outcome: "Leave problem for next president (Kennedy).")
                ]
            ),

            HistoricalCrisis(
                id: "ike_khrushchev_visit_1959",
                title: "Khrushchev Visits America",
                year: 1959,
                description: "Khrushchev wants to visit Disneyland. Security concerns. He's volatile - humiliating him risks nuclear incident. Camp David talks scheduled.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Allow full tour including Disneyland", outcome: "Khrushchev pleased. Brief thaw in relations."),
                    CrisisOption(title: "Restrict visit for security", outcome: "Khrushchev insulted. Storms out."),
                    CrisisOption(title: "Cancel visit entirely", outcome: "Major diplomatic incident."),
                    CrisisOption(title: "Camp David only", outcome: "Compromise. Some progress.")
                ]
            ),

            HistoricalCrisis(
                id: "ike_military_industrial_1961",
                title: "Military-Industrial Complex Warning",
                year: 1961,
                description: "Your farewell address. Defense contractors have immense political power. Do you warn America about the 'military-industrial complex'?",
                countries: [],
                options: [
                    CrisisOption(title: "Deliver warning publicly", outcome: "Historic speech. Defense industry furious. Prophetic."),
                    CrisisOption(title: "Private warnings only", outcome: "No public impact. Problem grows."),
                    CrisisOption(title: "Say nothing", outcome: "Complex grows unchecked."),
                    CrisisOption(title: "Praise defense industry", outcome: "Eisenhower legacy less principled.")
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
                    CrisisOption(title: "Authorize invasion with air support", outcome: "Still fails but with US complicity. International condemnation."),
                    CrisisOption(title: "Authorize but no air support", outcome: "Catastrophic failure. 114 killed, 1,189 captured. You're blamed."),
                    CrisisOption(title: "Cancel operation", outcome: "Exiles furious. CIA angry. Castro remains."),
                    CrisisOption(title: "Full US military invasion", outcome: "Success but USSR may put missiles in Cuba later.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_vienna_summit_1961",
                title: "Vienna Summit - Khrushchev Bullies",
                year: 1961,
                description: "Khrushchev bullies you at Vienna summit, sees you as weak after Bay of Pigs. Threatens war over Berlin. Says he'll bury you.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Stand firm on Berlin", outcome: "Khrushchev builds Berlin Wall. Crisis continues."),
                    CrisisOption(title: "Threaten nuclear war", outcome: "Massive escalation. Extremely dangerous."),
                    CrisisOption(title: "Negotiate Berlin compromise", outcome: "Seen as weakness. Wall built anyway."),
                    CrisisOption(title: "Military buildup in Europe", outcome: "Arms race accelerates. Tensions high.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_berlin_wall_1961",
                title: "Berlin Wall Construction",
                year: 1961,
                description: "East Germany begins building wall dividing Berlin overnight. Tanks face each other at Checkpoint Charlie. Military wants to bulldoze wall. Khrushchev dares you.",
                countries: ["USSR", "Germany"],
                options: [
                    CrisisOption(title: "Knock down wall with military", outcome: "WW3 starts immediately. Nuclear exchange likely."),
                    CrisisOption(title: "Accept wall but protest", outcome: "Wall stands. You give 'Ich bin ein Berliner' speech."),
                    CrisisOption(title: "Threaten nuclear retaliation", outcome: "Brinkmanship. Wall stays."),
                    CrisisOption(title: "Ignore wall", outcome: "Seen as weakness. Eastern Bloc emboldened.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_cuban_missile_1962",
                title: "Cuban Missile Crisis - Day 1",
                year: 1962,
                description: "U-2 photos show Soviet nuclear missiles in Cuba. 90 miles from Florida. Still being assembled. Khrushchev lied to you. JCS recommends immediate air strikes.",
                countries: ["Cuba", "USSR"],
                options: [
                    CrisisOption(title: "Naval blockade ('quarantine')", outcome: "13-day standoff. Khrushchev backs down. World at brink."),
                    CrisisOption(title: "Air strikes on missile sites", outcome: "May not get them all. Soviet casualties. Escalation."),
                    CrisisOption(title: "Invasion of Cuba", outcome: "USSR retaliates in Berlin or Turkey. WW3."),
                    CrisisOption(title: "Accept missiles in Cuba", outcome: "Political suicide. US vulnerable.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_cuban_missile_peak_1962",
                title: "Cuban Missile Crisis - Day 13",
                year: 1962,
                description: "Soviet ship approaches quarantine line. Your orders: fire if they don't stop. Khrushchev hasn't responded to your offer. World holds breath.",
                countries: ["Cuba", "USSR"],
                options: [
                    CrisisOption(title: "Secret deal: missiles out, no Cuba invasion", outcome: "Crisis ends. Secret Turkey missile removal. You're hero."),
                    CrisisOption(title: "Fire on Soviet ship", outcome: "Escalation to nuclear war begins."),
                    CrisisOption(title: "Let ship through", outcome: "Blockade fails. Khrushchev wins."),
                    CrisisOption(title: "Ultimatum: 24 hours or invasion", outcome: "Extremely dangerous. May work.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_birmingham_1963",
                title: "Birmingham - Bull Connor's Dogs",
                year: 1963,
                description: "Bull Connor orders police dogs and fire hoses on peaceful protesters. Images shock world. King writes from jail. South threatens secession if you intervene.",
                countries: [],
                options: [
                    CrisisOption(title: "Send federal troops", outcome: "Integration forced. South furious. 1964 Civil Rights Act possible."),
                    CrisisOption(title: "Negotiate with Wallace", outcome: "He refuses. Crisis continues."),
                    CrisisOption(title: "Stay out of 'state matter'", outcome: "Violence continues. Legacy damaged."),
                    CrisisOption(title: "Arrest Connor on federal charges", outcome: "Constitutional crisis. Bold move.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_vietnam_advisors_1963",
                title: "Vietnam - Diem Coup",
                year: 1963,
                description: "South Vietnam's Diem is brutal dictator. Buddhist monks self-immolate. CIA says generals will coup with US blessing. Advisors divided.",
                countries: ["Vietnam"],
                options: [
                    CrisisOption(title: "Green-light coup", outcome: "Diem assassinated. Chaos in South Vietnam. US blamed."),
                    CrisisOption(title: "Support Diem", outcome: "Buddhists revolt. South Vietnam unstable."),
                    CrisisOption(title: "Withdraw advisors", outcome: "South Vietnam falls to communism. Domino effect."),
                    CrisisOption(title: "Demand Diem reforms", outcome: "He refuses. Crisis continues.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_test_ban_1963",
                title: "Nuclear Test Ban Treaty Negotiations",
                year: 1963,
                description: "Khrushchev proposes ban on atmospheric nuclear tests. Military opposes - says we need testing. Environmentalists support - radiation concerns.",
                countries: ["USSR"],
                options: [
                    CrisisOption(title: "Sign Limited Test Ban Treaty", outcome: "Historic arms control. Underground testing continues."),
                    CrisisOption(title: "Reject treaty", outcome: "Arms race continues unchecked. Fallout increases."),
                    CrisisOption(title: "Demand comprehensive ban", outcome: "USSR refuses. No agreement."),
                    CrisisOption(title: "Sign but violate secretly", outcome: "Eventually exposed. Trust destroyed.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_laos_1961",
                title: "Laos Civil War",
                year: 1961,
                description: "Communist Pathet Lao winning civil war. Thailand and South Vietnam threatened. JCS wants 60,000 troops. Eisenhower called this 'cork in bottle.'",
                countries: [],
                options: [
                    CrisisOption(title: "Send troops to Laos", outcome: "Quagmire. Diverts from Vietnam."),
                    CrisisOption(title: "Covert support only", outcome: "Secret war. CIA expands operations."),
                    CrisisOption(title: "Negotiate neutral Laos", outcome: "Compromise. Communists eventually win."),
                    CrisisOption(title: "Let Laos fall", outcome: "Domino theory proven? Vietnam next.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_freedom_riders_1961",
                title: "Freedom Riders Attacked",
                year: 1961,
                description: "Integrated buses attacked in Alabama. Riders beaten, bus firebombed. Governor Patterson refuses protection. Attorney General (your brother Bobby) urges action.",
                countries: [],
                options: [
                    CrisisOption(title: "Federal marshals protect riders", outcome: "Riders succeed. South angry. Civil rights progress."),
                    CrisisOption(title: "Negotiate 'cooling off period'", outcome: "Riders refuse. You look weak."),
                    CrisisOption(title: "No federal intervention", outcome: "Violence continues. Movement grows."),
                    CrisisOption(title: "Arrest segregationists", outcome: "Legal battles. Bold statement.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_steel_crisis_1962",
                title: "Steel Price Crisis",
                year: 1962,
                description: "US Steel raises prices 3.5% despite your negotiated wage freeze. Inflation threatens economy. You're furious at being double-crossed.",
                countries: [],
                options: [
                    CrisisOption(title: "Force price rollback (FBI, IRS pressure)", outcome: "Steel caves. Business community furious. 'Dictatorial.'"),
                    CrisisOption(title: "Accept price increase", outcome: "Inflation rises. You look powerless."),
                    CrisisOption(title: "Negotiate compromise", outcome: "Partial rollback. Limited success."),
                    CrisisOption(title: "Threaten nationalization", outcome: "Extreme. Market panic.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_ole_miss_1962",
                title: "Ole Miss Integration - James Meredith",
                year: 1962,
                description: "Governor Barnett physically blocks Meredith from attending Ole Miss. Riots erupt. 2 dead. Federal marshals under siege. Mississippi in open rebellion.",
                countries: [],
                options: [
                    CrisisOption(title: "Send Army to enforce integration", outcome: "Meredith enrolls. Mississippi seethes. Federal power asserted."),
                    CrisisOption(title: "Negotiate with Barnett", outcome: "He breaks every agreement. You look foolish."),
                    CrisisOption(title: "Back down to avoid bloodshed", outcome: "Federal courts defied. Massive precedent."),
                    CrisisOption(title: "Arrest Barnett", outcome: "Bold but risky. Constitutional showdown.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_birmingham_church_1963",
                title: "Birmingham Church Bombing",
                year: 1963,
                description: "KKK bombs 16th Street Baptist Church. 4 little girls killed. National outrage. King demands federal action. Wallace defiant.",
                countries: [],
                options: [
                    CrisisOption(title: "FBI manhunt, federal charges", outcome: "Some bombers caught decades later. Civil Rights Act momentum."),
                    CrisisOption(title: "Federalize Alabama National Guard", outcome: "Direct confrontation with Wallace."),
                    CrisisOption(title: "Propose strong Civil Rights bill", outcome: "Passes after your death (1964)."),
                    CrisisOption(title: "States' rights approach", outcome: "Justice delayed decades.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_march_on_washington_1963",
                title: "March on Washington",
                year: 1963,
                description: "250,000 marching on Washington. King will give major speech. Conservatives fear riots. Do you publicly support or maintain distance?",
                countries: [],
                options: [
                    CrisisOption(title: "Publicly endorse march", outcome: "Historic moment. Civil Rights Act supported. South furious."),
                    CrisisOption(title: "Meet King privately after", outcome: "Moderate approach. Some progress."),
                    CrisisOption(title: "Discourage march", outcome: "It happens anyway. You look tone-deaf."),
                    CrisisOption(title: "Massive security presence", outcome: "March proceeds peacefully. 'I Have a Dream' speech.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_south_vietnam_instability_1963",
                title: "South Vietnam Government Collapse",
                year: 1963,
                description: "Diem assassinated in US-backed coup (3 weeks ago). Chaos in Saigon. Viet Cong advancing. Advisors urge major troop deployment.",
                countries: ["Vietnam"],
                options: [
                    CrisisOption(title: "Major troop deployment (100K+)", outcome: "Full-scale war begins. (You're assassinated Nov 22, LBJ inherits)"),
                    CrisisOption(title: "Withdraw advisors", outcome: "South Vietnam likely falls."),
                    CrisisOption(title: "Stabilize with limited troops", outcome: "Slow escalation. Problem persists."),
                    CrisisOption(title: "Negotiate neutrality", outcome: "Unlikely to work.")
                ]
            ),

            HistoricalCrisis(
                id: "jfk_limited_test_ban_1963",
                title: "Limited Nuclear Test Ban Treaty Finalization",
                year: 1963,
                description: "Treaty ready to sign. Bans atmospheric/space/underwater tests (underground allowed). Military fears USSR will cheat. Senate ratification uncertain.",
                countries: ["USSR", "UK"],
                options: [
                    CrisisOption(title: "Sign treaty, push Senate ratification", outcome: "Passes 80-19. First arms control success. Legacy achievement."),
                    CrisisOption(title: "Add verification demands", outcome: "USSR walks away. No deal."),
                    CrisisOption(title: "Reject treaty", outcome: "Testing continues. Fallout increases. Arms race unchecked."),
                    CrisisOption(title: "Sign but prepare to abrogate", outcome: "Cynical approach. Eventually exposed.")
                ]
            )
        ]
    }

    // Placeholder for remaining 10 presidents - To be implemented
    // Each will have 10-15 crises for complete historical coverage

    static func johnsonCrises() -> [HistoricalCrisis] {
        // TODO: Gulf of Tonkin, Vietnam escalation, Great Society, Civil Rights Act, Voting Rights Act, Six-Day War, Detroit riots, MLK assassination, RFK assassination, etc.
        return []
    }

    static func nixonCrises() -> [HistoricalCrisis] {
        // TODO: Cambodia invasion, Kent State, Pentagon Papers, China opening, Yom Kippur War, OPEC embargo, Saturday Night Massacre, Watergate, resignation, etc.
        return []
    }

    static func fordCrises() -> [HistoricalCrisis] {
        // TODO: Vietnam fall, Mayaguez incident, Helsinki Accords, Nixon pardon, NYC fiscal crisis, assassination attempts, etc.
        return []
    }

    static func carterCrises() -> [HistoricalCrisis] {
        // TODO: Iran hostage crisis, Camp David Accords, Soviet Afghanistan invasion, SALT II, Three Mile Island, Nicaragua revolution, gas crisis, malaise speech, etc.
        return []
    }

    static func reaganCrises() -> [HistoricalCrisis] {
        // TODO: Assassination attempt, PATCO strike, Lebanon bombing, Grenada invasion, Iran-Contra, Libya bombing, INF Treaty, SDI, challenger disaster, etc.
        return []
    }

    static func bushSrCrises() -> [HistoricalCrisis] {
        // TODO: Panama invasion, Berlin Wall falls, Tiananmen Square, Kuwait invasion, Desert Storm, USSR collapse, Yugoslavia war, Somalia, etc.
        return []
    }

    static func clintonCrises() -> [HistoricalCrisis] {
        // TODO: Mogadishu, Haiti intervention, Oklahoma City, Bosnia, Monica Lewinsky, impeachment, Kosovo, Rwanda genocide response, etc.
        return []
    }

    static func bushJrCrises() -> [HistoricalCrisis] {
        // TODO: 9/11, Afghanistan invasion, Iraq WMD decision, Axis of Evil, Hurricane Katrina, Abu Ghraib, surge, financial crisis, etc.
        return []
    }

    static func obamaCrises() -> [HistoricalCrisis] {
        // TODO: Bin Laden raid, Arab Spring, Syria red line, Crimea annexation, ISIS rise, Iran deal, Cuba opening, Benghazi, etc.
        return []
    }

    static func trumpFirstCrises() -> [HistoricalCrisis] {
        // TODO: Charlottesville, North Korea threats, Iran deal withdrawal, COVID-19, Jan 6, impeachments, etc.
        return []
    }

    static func bidenCrises() -> [HistoricalCrisis] {
        // TODO: Afghanistan withdrawal, Ukraine invasion, Gaza war, Iran tensions, China Taiwan, etc.
        return []
    }

    static func trumpSecondCrises() -> [HistoricalCrisis] {
        // TODO: Future scenarios (hypothetical)
        return []
    }
}

// MARK: - Data Model

struct HistoricalCrisis: Identifiable, Codable {
    let id: String
    let title: String
    let year: Int
    let description: String
    let countries: [String]
    let options: [CrisisOption]

    var severity: CrisisSeverity {
        if title.contains("Nuclear") || title.contains("Missile") { return .catastrophic }
        if title.contains("War") || title.contains("Invasion") { return .critical }
        if title.contains("Crisis") { return .serious }
        return .moderate
    }

    enum CrisisSeverity: String {
        case catastrophic, critical, serious, moderate, minor
    }
}

struct CrisisOption: Identifiable, Codable {
    let id = UUID()
    let title: String
    let outcome: String

    var successChance: Double {
        // Estimate based on historical outcomes
        if outcome.contains("success") || outcome.contains("succeeds") { return 0.8 }
        if outcome.contains("fails") || outcome.contains("disaster") { return 0.3 }
        return 0.6
    }
}
