#!/usr/bin/env python3
"""Build a Markov chain model for Norwegian sentence generation.

Supports three modes:
  A) From NB N-gram corpus (Nasjonalbiblioteket):
       python3 build_markov_model.py --ngram-dir /path/to/ngrams --output ../../assets/markov/
  B) Bootstrap from curated sentence corpus:
       python3 build_markov_model.py --bootstrap --output ../../assets/markov/
  C) Hybrid (recommended — bootstrap provides starters/structure, NB adds frequency data):
       python3 build_markov_model.py --bootstrap --ngram-dir /path/to/ngrams --output ../../assets/markov/

Output (JSON, loadable by Dart):
  - markov_trigrams.json  — trigram transition table
  - markov_bigrams.json   — bigram transition table
  - markov_meta.json      — starters, enders, vocab stats
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

# ---------------------------------------------------------------------------
# Profanity filter – small set of Norwegian vulgarities to exclude
# ---------------------------------------------------------------------------
PROFANITY = frozenset([
    "faen", "jævel", "jævla", "helvete", "dritt", "drittunge",
    "fitte", "pikk", "kuk", "kukk", "hore", "ludder", "rass",
    "ræv", "ræva", "pule", "knulle", "satan", "satansen",
    "forbanna", "forpulte", "drittsekk", "hestkuk",
])

# ---------------------------------------------------------------------------
# Curated Norwegian bokmål sentences grouped by difficulty tier
# ---------------------------------------------------------------------------

SENTENCES_TIER1 = [
    # Simple declarative – short, common words
    "Jeg er glad i dag.",
    "Han spiser en pølse.",
    "Vi går på skolen.",
    "Hun liker å lese.",
    "Det er sol ute.",
    "Katten sover på sofaen.",
    "Hunden løper i parken.",
    "Vi bor i Norge.",
    "Mor lager god mat.",
    "Far kjører bil til jobb.",
    "Jeg har en bror.",
    "Hun har en søster.",
    "Vi spiser middag nå.",
    "De leker i hagen.",
    "Boken er på bordet.",
    "Jeg drikker melk.",
    "Han sover i sengen.",
    "Stolen er rød.",
    "Huset er hvitt.",
    "Døren er lukket.",
    "Vi ser en film.",
    "Hun synger en sang.",
    "Han spiller fotball.",
    "Det er kaldt ute.",
    "Det regner i dag.",
    "Vi liker is.",
    "Jeg har en hund.",
    "Katten er svart.",
    "Ballen er stor.",
    "Maten er god.",
    "Jeg liker kaffe.",
    "Hun leser en bok.",
    "Vi går hjem nå.",
    "Han sitter ved bordet.",
    "Klokken er fem.",
    "Det er vinter.",
    "Solen skinner.",
    "Barna leker ute.",
    "Faren venter hjemme.",
    "Moren er på jobb.",
    "Vi tar bussen.",
    "Toget er sent.",
    "Jeg er sulten.",
    "Hun er tørst.",
    "Det er tidlig.",
    "Det er sent.",
    "Vi sover nå.",
    "Han liker ost.",
    "Jeg ser en fugl.",
    "Fisken er i vannet.",
    "Det er en pen dag.",
    "Jeg har to barn.",
    "Vi har en katt.",
    "De bor i Oslo.",
    "Han går til byen.",
    "Jeg kjøper brød.",
    "Hun lager te.",
    "Vi har det bra.",
    "Det er fint vær.",
    "Gutten er glad.",
    "Jenta er snill.",
    "De er venner.",
    "Jeg vet ikke.",
    "Han er stor.",
    "Stolen er grønn.",
    "Bordet er lite.",
    "Lampen er gul.",
    "Veien er lang.",
    "Skogen er mørk.",
    "Sjøen er blå.",
    "Fjellet er høyt.",
    "Snøen er hvit.",
    "Vinden er kald.",
    "Regnet er tungt.",
    "Natten er stille.",
    "Dagen er kort.",
    "Livet er godt.",
    "Hagen er fin.",
    "Parken er stor.",
    "Gaten er bred.",
    "Broen er lang.",
    "Elven er dyp.",
    "Treet er grønt.",
    "Blomsten er rød.",
    "Eplet er søtt.",
    "Brødet er ferskt.",
    "Osten er god.",
    "Melken er kald.",
    "Suppen er varm.",
    "Kaken er stor.",
    "Bilen er ny.",
    "Sykkelen er blå.",
    "Bussen er full.",
    "Flyet er stort.",
    "Båten er liten.",
    "Tog er rask.",
    "Vi leker sammen.",
    "De løper fort.",
    "Han hopper høyt.",
    "Hun svømmer godt.",
    "Jeg maler et bilde.",
    "Vi synger sammen.",
    "De danser i ring.",
    "Hva gjør du?",
    "Hvor bor du?",
    "Hvor er du?",
    "Hva heter du?",
    "Har du tid?",
    "Hva spiser du?",
    "Liker du kaffe?",
    "Kan du hjelpe meg?",
    "Er du klar?",
    "Skal vi gå?",
]

SENTENCES_TIER2 = [
    # Slightly longer simple sentences
    "Jeg skal på skolen i morgen.",
    "Vi spiser frokost klokken sju.",
    "Hun jobber på et kontor.",
    "Han liker å gå tur i skogen.",
    "Barna går i barnehagen.",
    "Vi reiser til Bergen i sommer.",
    "Familien spiser sammen hver dag.",
    "Hunden vår heter Rex.",
    "Katten min liker å sove.",
    "Det er mange bøker i hyllen.",
    "Vi handler mat på butikken.",
    "Hun tar bussen til jobb.",
    "Han spiller gitar om kvelden.",
    "De ser på TV etter middag.",
    "Vi drikker kaffe til frokost.",
    "Moren min er lærer.",
    "Faren min er lege.",
    "Broren min er ti år.",
    "Søsteren min bor i Tromsø.",
    "Bestemor lager de beste kakene.",
    "Bestefar forteller fine historier.",
    "Naboen vår har tre katter.",
    "Vi har et stort hus.",
    "De bor i en liten by.",
    "Skolen vår er ganske ny.",
    "Klassen har tjue elever.",
    "Læreren er veldig snill.",
    "Vi har gym på tirsdager.",
    "De spiller fotball i friminuttet.",
    "Hun tegner pene bilder.",
    "Han skriver en lang stil.",
    "Vi lærer norsk på skolen.",
    "De liker å synge i kor.",
    "Hunden løper etter ballen.",
    "Katten jager en mus.",
    "Fuglen sitter i treet.",
    "Fisken svømmer i elven.",
    "Vi ser på stjernene om natten.",
    "Månen er full i kveld.",
    "Solen går ned bak fjellet.",
    "Det blåser mye i dag.",
    "Vi trenger en paraply.",
    "Han tar på seg jakken.",
    "Hun kler på seg varmt.",
    "Det snør mye i vinter.",
    "Isen er tykk på vannet.",
    "Vi går på skøyter.",
    "De står på ski.",
    "Han liker å stå på snowboard.",
    "Vi bygger en snømann.",
    "Barna leker i snøen.",
    "Våren kommer snart.",
    "Blomstene begynner å spire.",
    "Det er varmt om sommeren.",
    "Vi bader i sjøen.",
    "De griller i hagen.",
    "Han fisker ved vannet.",
    "Vi plukker bær i skogen.",
    "Høsten er vakker i Norge.",
    "Bladene faller fra trærne.",
    "Det er mørkt om vinteren.",
    "Vi tenner lys i adventstiden.",
    "Julen er en fin høytid.",
    "Vi feirer jul med familien.",
    "Nyttårsaften er den siste dagen i året.",
    "Vi feirer bursdagen min i mars.",
    "Han fikk en ny sykkel i gave.",
    "Hun ønsker seg en bok til jul.",
    "Vi baker pepperkaker i desember.",
    "De pynter juletreet sammen.",
    "Maten smaker godt i dag.",
    "Suppen er veldig varm.",
    "Vi lager pizza til kveldsmat.",
    "Hun baker en sjokoladekake.",
    "Han steker fisk til middag.",
    "Vi koker poteter og grønnsaker.",
    "De bestiller mat fra en restaurant.",
    "Smørbrødet har ost og skinke.",
    "Salaten er frisk og god.",
    "Frokosten er den viktigste måltidet.",
    "Jeg går til sengs klokken ti.",
    "De våkner tidlig om morgenen.",
    "Vi pusser tennene to ganger om dagen.",
    "Hun tar en dusj etter trening.",
    "Han liker å lese før han sover.",
    "Vi rydder rommet vårt.",
    "De vasker klærne på lørdag.",
    "Oppvaskmaskinen er full.",
    "Vi støvsuger stuen.",
    "Han klipper gresset i hagen.",
    "Hun vanner blomstene.",
    "Vi maler soverommet blått.",
    "De reparerer taket på huset.",
    "Bilen trenger ny olje.",
    "Vi fyller bensin på stasjonen.",
    "Dekkene er gamle.",
    "Han vasker bilen hver uke.",
    "Jeg gleder meg til ferien.",
    "Vi reiser med fly til Spania.",
    "Hotellet ligger ved stranden.",
    "De besøker museer og gallerier.",
]

SENTENCES_TIER3 = [
    # Medium complexity – richer vocabulary, longer structures
    "Familien reiste til fjellene i sommer.",
    "Læreren forklarte oppgaven veldig godt.",
    "Butikken stenger klokken åtte i kveld.",
    "Vi feiret nasjonaldagen med flagg og is.",
    "Toget ankom stasjonen ti minutter for sent.",
    "Restauranten serverer tradisjonell norsk mat.",
    "Været skifter ofte i Norge om høsten.",
    "Kommunen har bygget en ny svømmehall.",
    "Elevene hadde eksamen i matematikk forrige uke.",
    "Biblioteket har tusenvis av bøker å låne.",
    "Naboen inviterte oss på grillfest i helgen.",
    "Orkesteret øvde på konserten i flere uker.",
    "Ungdommene arrangerte en stor musikkfestival.",
    "Legene anbefaler å trene minst tre ganger i uken.",
    "Flyet til London ble kansellert på grunn av tåke.",
    "Politiet etterforsker et innbrudd i nabolaget.",
    "Brannvesenet kom raskt til stedet.",
    "Sykehuset har fått nytt medisinsk utstyr.",
    "Fotballaget vant kampen med tre mål.",
    "Svømmeren satte ny norsk rekord.",
    "Skiløperen trente hardt hele sommeren.",
    "Kunstneren åpnet en ny utstilling på galleriet.",
    "Forfatteren ga ut en ny roman i høst.",
    "Filmen fikk gode anmeldelser i avisene.",
    "Konserten ble utsolgt på bare to dager.",
    "Teateret setter opp et nytt stykke i vår.",
    "Museet har en spennende utstilling om vikingene.",
    "Festivalen trekker besøkende fra hele landet.",
    "Konferansen handler om bærekraftig utvikling.",
    "Semesteret starter i august hvert år.",
    "Studentene forbereder seg til eksamen.",
    "Universitetet tilbyr mange forskjellige studier.",
    "Forskningen viser at mosjon er viktig for helsen.",
    "Rapporten ble publisert i forrige uke.",
    "Statistikken viser en økning i turismen.",
    "Økonomien vokser sakte, men sikkert.",
    "Prisene på boliger har steget det siste året.",
    "Renten er lav for tiden.",
    "Arbeidsledigheten har gått ned i det siste.",
    "Regjeringen presenterte et nytt statsbudsjett.",
    "Stortinget vedtok en ny lov om personvern.",
    "Valgkampen er i full gang.",
    "Partiene diskuterer klima og miljøpolitikk.",
    "Kommunevalget finner sted i september.",
    "Ordføreren holdt en tale på rådhuset.",
    "Det frivillige arbeidet er viktig for samfunnet.",
    "Organisasjonen hjelper mennesker i nød.",
    "Røde Kors samler inn penger til hjelpearbeid.",
    "Naturen i Norge er kjent for sin skjønnhet.",
    "Fjordene er en populær turistattraksjon.",
    "Nordlyset kan sees fra Nord-Norge om vinteren.",
    "Midnattssolen er et unikt fenomen i nord.",
    "Kysten strekker seg over tusenvis av kilometer.",
    "Norges nasjonaldag feires den syttende mai.",
    "Bunadene er en viktig del av tradisjonen.",
    "Stortinget ligger i sentrum av Oslo.",
    "Bryggen i Bergen er på verdensarvlisten.",
    "Vigelandsparken er en kjent skulpturpark.",
    "Operahuset i Oslo er et moderne landemerke.",
    "Lofoten er kjent for sitt dramatiske landskap.",
    "Hurtigruten seiler langs norskekysten.",
    "Trolltunga er et populært turmål.",
    "Preikestolen trekker mange turister hvert år.",
    "Hardangervidda er Norges største nasjonalpark.",
    "Jotunheimen har noen av de høyeste fjellene.",
    "Galdhøpiggen er det høyeste fjellet i Norge.",
    "Jostedalsbreen er den største isbreen i Europa.",
    "Sognefjorden er den lengste fjorden i Norge.",
    "De norske skogene har mange ville dyr.",
    "Elgen er Norges største dyr.",
    "Reinsdyr lever i fjellområdene.",
    "Havørnen hekker langs kysten.",
    "Laks og ørret finnes i mange norske elver.",
    "Torsken er viktig for fiskerinæringen.",
    "Oppdrettsnæringen er en stor industri i Norge.",
    "Olje og gass er fortsatt viktige ressurser.",
    "Vannkraft gir mesteparten av strømmen i Norge.",
    "Elbiler er svært populære i Norge.",
    "Kollektivtransporten er godt utbygd i byene.",
    "Sykkelveier bygges ut i mange byer.",
    "Jernbanen forbinder de største byene.",
    "Flyrutene dekker hele landet.",
    "Tunneler gjør reisen enklere gjennom fjellene.",
    "Broer forbinder mange øyer med fastlandet.",
    "Fergene er viktige for transport langs kysten.",
    "Veiene i Norge kan være utfordrende om vinteren.",
    "Brøytebilene jobber døgnet rundt.",
    "Saltbilen holder veiene fri for is.",
    "Vinterdekk er påbudt fra november.",
    "Kjørelysene skal alltid være på i Norge.",
    "Fartgrensen er vanligvis åtti kilometer i timen.",
    "Bomstasjoner er vanlige på norske veier.",
    "Parkeringen i sentrum er dyr.",
    "Vi handler dagligvarer på Rema og Kiwi.",
    "Mange nordmenn har hytte på fjellet.",
    "Påskeferie på hytta er en norsk tradisjon.",
    "Kvikk Lunsj og appelsiner hører påsken til.",
    "Nordmenn elsker friluftsliv.",
    "Turgåing er den mest populære fritidsaktiviteten.",
    "Bålmat smaker ekstra godt ute i naturen.",
]

SENTENCES_TIER4 = [
    # Complex – formal, compound structures
    "Utenriksministeren understreket betydningen av internasjonalt samarbeid.",
    "Forskerne publiserte resultatene i et anerkjent tidsskrift.",
    "Klimaendringene påvirker norsk natur og dyreliv i økende grad.",
    "Digitaliseringen av offentlige tjenester fortsetter i høyt tempo.",
    "Integreringspolitikken står sentralt i den politiske debatten.",
    "Helsevesenet står overfor store utfordringer i årene fremover.",
    "Utdanningssystemet gjennomgår en betydelig modernisering.",
    "Næringslivet investerer tungt i grønn teknologi.",
    "Kulturbudsjettet ble økt med fem prosent i det nye statsbudsjettet.",
    "Menneskerettighetene danner grunnlaget for det norske rettssystemet.",
    "Den teknologiske utviklingen skaper nye muligheter for arbeidslivet.",
    "Urbaniseringen fører til at flere mennesker flytter til byene.",
    "Befolkningsveksten i storbyene skaper behov for flere boliger.",
    "Distriktspolitikken er viktig for å opprettholde bosetting i hele landet.",
    "Samferdselsbudsjettet prioriterer vedlikehold av eksisterende infrastruktur.",
    "Investeringene i fornybar energi har økt betraktelig de siste årene.",
    "Petroleumsindustrien omstiller seg gradvis til grønnere drift.",
    "Fiskerinæringen er en av landets viktigste eksportnæringer.",
    "Skogbruket spiller en vesentlig rolle i den norske bioøkonomien.",
    "Jordbruket i Norge er tilpasset et utfordrende klima.",
    "Turismen bidrar i økende grad til verdiskapingen i distriktene.",
    "Innovasjonspolitikken legger til rette for ny næringsutvikling.",
    "Handelsavtalen med EU er avgjørende for norsk eksport.",
    "Utenrikspolitikken balanserer mellom sikkerhet og fredsarbeid.",
    "Nordområdepolitikken har fått større oppmerksomhet de siste årene.",
    "Forsvarsbudsjettet ble økt i tråd med internasjonale forpliktelser.",
    "Bistandsarbeidet fokuserer på utdanning og helsehjelp i utviklingsland.",
    "Diplomatiet spiller en viktig rolle i konflikthåndtering.",
    "Sikkerhetsrådet diskuterte situasjonen i regionen denne uken.",
    "Fredsforhandlingene ble gjenopptatt etter en lang pause.",
    "Klimaforhandlingene resulterte i en ambisiøs avtale mellom landene.",
    "Bærekraftsmålene danner rammen for den nasjonale utviklingspolitikken.",
    "Miljøvernorganisasjonene krever strengere regulering av utslipp.",
    "Forurensningen av havene er et globalt miljøproblem.",
    "Artsmangfoldet trues av menneskelig aktivitet og klimaendringer.",
    "Gjenvinningssystemet i Norge er blant de mest effektive i verden.",
    "Avfallshåndteringen har blitt betydelig forbedret de siste tiårene.",
    "Energieffektivisering er en viktig del av klimastrategien.",
    "Transportpolitikken legger vekt på å redusere klimagassutslipp.",
    "Elektrifiseringen av transportsektoren går raskere enn forventet.",
    "Personvernlovgivningen stiller strenge krav til behandling av data.",
    "Informasjonssikkerheten har blitt et prioritert område for myndighetene.",
    "Forskningsinstituttene samarbeider på tvers av landegrensene.",
    "Akademisk frihet er et grunnleggende prinsipp ved universitetene.",
    "Lærerutdanningen gjennomgikk en stor reform for noen år siden.",
    "Kompetanseutvikling er avgjørende for fremtidens arbeidsliv.",
    "Arbeidsmarkedet endrer seg raskt som følge av automatisering.",
    "Fagforeningene spiller en viktig rolle i det norske arbeidslivet.",
    "Velferdsordningene sikrer et grunnleggende nivå for alle innbyggere.",
    "Pensjonssystemet ble reformert for å sikre bærekraft på lang sikt.",
    "Domstolene har en uavhengig stilling i det norske rettssystemet.",
    "Ytringsfrihet er en grunnleggende rettighet i det norske demokratiet.",
    "Pressefrihet er avgjørende for et velfungerende samfunn.",
    "Mediemangfoldet sikres gjennom offentlig støtte og regulering.",
    "Kultursektoren ble hardt rammet av pandemien.",
    "Frivillig sektor bidrar enormt til det norske samfunnet.",
    "Idrettsorganisasjonene engasjerer hundretusenvis av nordmenn.",
    "Folkehelsen har generelt blitt bedre de siste tiårene.",
    "Psykisk helse har fått større oppmerksomhet i offentlig debatt.",
    "Primærhelsetjenesten er grunnmuren i det norske helsevesenet.",
    "Sykehusreformen endret organiseringen av spesialisthelsetjenesten.",
    "Legemiddelindustrien investerer i forskning og utvikling.",
    "Vaksinasjonsprogrammet dekker et bredt spekter av sykdommer.",
    "Eldreomsorgen står overfor kapasitetsutfordringer fremover.",
    "Barnevernet har som oppgave å sikre barns rettigheter.",
    "Likestillingspolitikken har lange tradisjoner i Norge.",
    "Urfolksrettighetene er beskyttet gjennom grunnloven.",
    "Sametinget representerer den samiske befolkningen i Norge.",
    "Minoritetsspråkene har et særskilt vern i norsk lovgivning.",
    "Innvandringspolitikken er et tema som engasjerer mange velgere.",
    "Integreringsarbeidet krever innsats fra hele samfunnet.",
    "Språkopplæring er en nøkkel til vellykket integrering.",
    "Boligmarkedet i de største byene er preget av høye priser.",
    "Byggebransjen opplever mangel på kvalifisert arbeidskraft.",
    "Arkitekturen i norske byer gjenspeiler mange ulike epoker.",
    "Kulturminnevernet beskytter historiske bygninger og områder.",
    "Arkeologiske funn gir ny kunnskap om fortidens samfunn.",
    "Museene formidler kunnskap og opplevelser til et bredt publikum.",
    "Litteraturen har en sterk posisjon i norsk kulturliv.",
    "Teaterinstitusjonene tilbyr et mangfoldig repertoar.",
    "Filmbransjen har opplevd en internasjonal oppblomstring.",
    "Musikkindustrien i Norge har fostret flere internasjonale artister.",
    "Den norske mattradisjonen opplever en fornyet interesse.",
    "Gastronomien har utviklet seg kraftig de siste tiårene.",
    "Lokale råvarer danner grunnlaget for det nye norske kjøkkenet.",
    "Matfestivalene trekker besøkende fra inn- og utland.",
    "Sjømatnæringen eksporterer til mer enn hundre land.",
    "Havbruksindustrien er blant verdens mest avanserte.",
    "Bærekraftig forvaltning av havressursene er helt avgjørende.",
    "Forskningsfartøyene kartlegger livet i de norske havområdene.",
    "Teknologiutviklingen innen havbruk skjer i raskt tempo.",
    "Norsk design har fått økt internasjonal anerkjennelse.",
    "Arkitektfirmaene konkurrerer om prestisjeprosjekter over hele verden.",
    "Designmiljøet i Oslo har vokst betydelig de siste årene.",
    "Programmering og teknologi undervises stadig tidligere i skolene.",
    "Kunstig intelligens forventes å endre mange bransjer fremover.",
    "Romforskningen gir ny innsikt om universet og vår plass i det.",
    "Polarforskningen har lange tradisjoner ved norske institusjoner.",
    "Oseanografien bidrar til forståelsen av klimasystemet.",
    "Geologisk kartlegging avdekker nye mineralforekomster.",
]

SENTENCES_TIER5 = [
    # Very complex – academic, bureaucratic, lengthy
    "Grunnlovsendringen ble vedtatt med kvalifisert flertall etter grundig debatt i Stortinget.",
    "Konsekvensutredningen viste at tiltaket ville ha begrenset innvirkning på det biologiske mangfoldet.",
    "Forvaltningsreformen medførte en betydelig omorganisering av det regionale forvaltningsnivået.",
    "Handlingsplanen for likestilling mellom kjønnene inneholder konkrete tiltak på flere samfunnsområder.",
    "Innovasjonsstrategien prioriterer forskning og utvikling innen bærekraftige teknologier og grønn omstilling.",
    "Konkurransetilsynet gjennomførte en omfattende analyse av markedsforholdene i dagligvarebransjen.",
    "Universitetsstyret vedtok en ny strategi for internasjonalisering av forskning og utdanning.",
    "Kommunereformen har resultert i færre, men større og mer robuste kommuner over hele landet.",
    "Folkehelserapporten dokumenterer store forskjeller i helse mellom ulike befolkningsgrupper.",
    "Infrastrukturprosjektet vil forbinde de to byene med en moderne motorveiforbindelse.",
    "Stortingsmeldingen om langtidsplanen for forskning og høyere utdanning ble lagt frem i høst.",
    "Kvalitetssikringssystemet for høyere utdanning bygger på internasjonale standarder og retningslinjer.",
    "Handelsbalansen ble påvirket av fallende oljepriser og økt import av konsumvarer.",
    "Reguleringsplanen for det nye boligområdet ble sendt ut på offentlig høring denne måneden.",
    "Eiendomsutviklerne presenterte et ambisiøst prosjekt for bærekraftig byutvikling i sentrumsområdet.",
    "Transportøkonomisk institutt har beregnet de samfunnsøkonomiske kostnadene ved veiprosjektet.",
    "Fylkeskommunen har ansvaret for videregående opplæring og regional kollektivtransport.",
    "Statsforvalteren fører tilsyn med kommunenes etterlevelse av lover og forskrifter.",
    "Datatilsynet mottok et rekordhøyt antall klager knyttet til personvernbrudd i fjor.",
    "Riksrevisjonen avdekket mangler i departementets oppfølging av vedtatte klimamål.",
    "Norges forskningsråd tildelte midler til flere tverrfaglige forskningsprosjekter om bærekraft.",
    "Finanstilsynet vurderer fortløpende den finansielle stabiliteten i det norske banksystemet.",
    "Arbeidstilsynets inspeksjoner avdekket brudd på arbeidsmiljøloven i flere virksomheter.",
    "Petroleumstilsynet stiller strenge krav til sikkerhet og miljø på norsk sokkel.",
    "Helsedirektoratets retningslinjer for behandling av kroniske sykdommer ble oppdatert i år.",
    "Utlendingsdirektoratet behandlet et betydelig antall søknader om beskyttelse og oppholdstillatelse.",
    "Kystverket har ansvaret for navigasjonssikkerhet og beredskap mot akutt forurensning.",
    "Meteorologisk institutt varslet ekstremvær med kraftig vind og store nedbørsmengder langs kysten.",
    "Vegvesenets planer for utbygging av hovedveiene ble presentert i nasjonal transportplan.",
    "Jernbanedirektoratet arbeider med å forbedre togtilbudet på de mest trafikkerte strekningene.",
    "Avinor investerer i modernisering av flyplassinfrastrukturen for å møte fremtidig trafikkvekst.",
    "Oljefondet har en diversifisert portefølje av aksjer, obligasjoner og eiendom over hele verden.",
    "Sentralbanken justerte styringsrenten for å balansere hensynet til prisstabilitet og sysselsetting.",
    "Skatteetaten gjennomfører omfattende digitaliseringsprosjekter for å forenkle rapportering og kontroll.",
    "Tolletaten samarbeider internasjonalt for å bekjempe grensekryssende kriminalitet og smugling.",
    "Mattilsynet fører tilsyn med matproduksjon og dyrevelferd i hele verdikjeden.",
    "Miljødirektoratet koordinerer arbeidet med forvaltningsplaner for de norske havområdene.",
    "Kartverket produserer og forvalter geografisk informasjon for bruk i offentlig og privat sektor.",
    "Statistisk sentralbyrå publiserer regelmessig oppdaterte tall om økonomi, befolkning og samfunn.",
    "Nasjonalbiblioteket har som oppgave å samle inn og bevare alt som publiseres i Norge.",
    "Riksantikvaren gir råd og veiledning om vern og forvaltning av kulturminner og kulturmiljøer.",
    "Direktoratet for samfunnssikkerhet koordinerer den nasjonale beredskapen mot alvorlige hendelser.",
    "Sivilombudet behandler klager fra borgere som mener de er utsatt for urett fra forvaltningen.",
    "Pasient- og brukerombudet bistår personer som opplever mangler i helse- og omsorgstjenestene.",
    "Likestillings- og diskrimineringsombudet arbeider for å fremme likestilling og bekjempe diskriminering.",
    "Forbrukerrådet gir veiledning om forbrukerrettigheter og bistår i tvister mellom forbrukere og næringsdrivende.",
    "Barneombudet fremmer barns interesser og rettigheter overfor offentlige og private aktører.",
    "Språkrådet arbeider med å styrke norsk språk og språkmangfoldet i det norske samfunnet.",
    "Kulturrådet fordeler statlige midler til kunst- og kulturformål over hele landet.",
    "Forskningsetiske komiteer sikrer at forskning gjennomføres i tråd med etiske retningslinjer.",
]


def get_all_sentences():
    """Return all curated sentences grouped by tier."""
    return {
        1: SENTENCES_TIER1,
        2: SENTENCES_TIER2,
        3: SENTENCES_TIER3,
        4: SENTENCES_TIER4,
        5: SENTENCES_TIER5,
    }


# ---------------------------------------------------------------------------
# Tokenisation helpers
# ---------------------------------------------------------------------------

_TOKEN_RE = re.compile(r"[A-ZÆØÅa-zæøåéèêëàáâãäüöïîìíòóôõúùûýñç0-9]+(?:[-'][A-ZÆØÅa-zæøåéèêëàáâãäüöïîìíòóôõúùûýñç0-9]+)*|[.!?,:;]")


def tokenise(sentence: str) -> list[str]:
    """Tokenise a Norwegian sentence, keeping punctuation as separate tokens."""
    return _TOKEN_RE.findall(sentence)


def is_sentence_end(token: str) -> bool:
    return token in (".", "!", "?")


def is_clean(word: str) -> bool:
    """Return False if word is profane, punctuation, or not a real word."""
    if word.lower() in PROFANITY:
        return False
    # Must contain at least one letter
    if not any(c.isalpha() for c in word):
        return False
    return True


# ---------------------------------------------------------------------------
# Model builder
# ---------------------------------------------------------------------------

class MarkovModelBuilder:
    def __init__(self):
        self.bigram_counts: dict[str, Counter] = defaultdict(Counter)
        self.trigram_counts: dict[tuple[str, str], Counter] = defaultdict(Counter)
        self.starters: Counter = Counter()  # (w1, w2) that start sentences
        self.enders: Counter = Counter()    # words before sentence-end punctuation
        self.vocab: Counter = Counter()
        self.word_tiers: dict[str, int] = {}  # word → lowest tier it appears in

    def add_sentence(self, sentence: str, weight: int = 1, tier: int | None = None):
        tokens = tokenise(sentence)
        if len(tokens) < 2:
            return

        # Track vocabulary
        for t in tokens:
            if not is_sentence_end(t) and is_clean(t):
                self.vocab[t.lower()] += weight
                if tier is not None:
                    cur = self.word_tiers.get(t.lower(), 99)
                    self.word_tiers[t.lower()] = min(cur, tier)

        # Identify starters: first two real words of the sentence
        real = [t for t in tokens if is_clean(t)]
        if len(real) >= 2:
            self.starters[(real[0], real[1])] += weight

        # Identify enders: word right before sentence-ending punctuation
        for i, t in enumerate(tokens):
            if is_sentence_end(t) and i > 0:
                prev = tokens[i - 1]
                if is_clean(prev):
                    self.enders[prev.lower()] += weight

        # Build bigrams (over all tokens including punctuation)
        for i in range(len(tokens) - 1):
            w1, w2 = tokens[i].lower(), tokens[i + 1].lower()
            if is_clean(w1) and is_clean(w2):
                self.bigram_counts[w1][w2] += weight

        # Build trigrams
        for i in range(len(tokens) - 2):
            w1, w2, w3 = tokens[i].lower(), tokens[i + 1].lower(), tokens[i + 2].lower()
            if is_clean(w1) and is_clean(w2) and is_clean(w3):
                self.trigram_counts[(w1, w2)][w3] += weight

    def add_ngram_file(self, path: str, n: int):
        """Parse an NB N-gram corpus file.

        Supports two formats:
          A) NB Språkbanken:  <freq> <w1> <w2> …     (space-separated, freq first)
          B) Tab-separated:   <w1> <w2> …\\t<freq>    (words first, freq last)

        Sentence boundary tokens (<s>, </s>) are skipped.
        """
        count = 0
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                # Try tab-separated format first (words\tfreq)
                tab_parts = line.rsplit("\t", 1)
                if len(tab_parts) == 2:
                    words_part, freq_str = tab_parts
                    try:
                        freq = int(freq_str)
                        words = words_part.split()
                    except ValueError:
                        freq = None
                        words = None
                else:
                    freq = None
                    words = None

                # Fall back to NB format (freq words...)
                if freq is None:
                    space_parts = line.split()
                    if len(space_parts) >= 2:
                        try:
                            freq = int(space_parts[0])
                            words = space_parts[1:]
                        except ValueError:
                            continue
                    else:
                        continue

                if words is None or len(words) != n:
                    continue

                # Handle sentence-boundary tokens for starters/enders
                has_start = "<s>" in words
                has_end = "</s>" in words

                if has_start or has_end:
                    if n == 3:
                        # <s> w1 w2 → sentence starter
                        if words[0] == "<s>" and words[1] != "</s>" and words[2] != "</s>":
                            w1, w2 = words[1].lower(), words[2].lower()
                            if is_clean(words[1]) and is_clean(words[2]):
                                self.starters[(w1, w2)] += freq
                        # w1 w2 </s> → sentence ender
                        # Often "w1 . </s>" — use w1 (word before punct)
                        if words[2] == "</s>" and words[0] != "<s>":
                            if words[1] in (".", "!", "?", "…"):
                                # Punctuation ending — real ender is w0
                                if is_clean(words[0]):
                                    self.enders[words[0].lower()] += freq
                            elif words[1] != "<s>" and is_clean(words[1]):
                                self.enders[words[1].lower()] += freq
                    continue

                # Filter profanity and non-word tokens
                if not all(is_clean(w) for w in words):
                    continue

                if n == 2:
                    w1, w2 = words[0].lower(), words[1].lower()
                    self.bigram_counts[w1][w2] += freq
                    self.vocab[w1] += freq
                    self.vocab[w2] += freq
                elif n == 3:
                    w1, w2, w3 = words[0].lower(), words[1].lower(), words[2].lower()
                    self.trigram_counts[(w1, w2)][w3] += freq
                    self.vocab[w1] += freq
                    self.vocab[w2] += freq
                    self.vocab[w3] += freq

                    # Heuristic enders: word before sentence-final punctuation
                    if w3 in (".", "!", "?", "…"):
                        self.enders[w2] += freq

                count += 1
                if count % 500_000 == 0:
                    print(f"  … processed {count:,} {n}-grams")

        print(f"  Loaded {count:,} {n}-grams from {path}")

    def _normalise(self, counter: Counter, top_k: int | None = None) -> list[list]:
        """Convert a Counter to a sorted [(token, probability), ...] list."""
        if not counter:
            return []
        items = counter.most_common(top_k)
        total = sum(c for _, c in items)
        return [[tok, round(c / total, 6)] for tok, c in items]

    def build(self, vocab_filter: set[str] | None = None,
              min_bigram_freq: int = 5,
              min_trigram_freq: int = 3,
              max_bigram_contexts: int = 15000,
              max_trigram_contexts: int = 30000,
              max_starters: int = 500,
              max_enders: int = 500) -> dict:
        """Build the final model dictionaries.

        Args:
            vocab_filter: Set of allowed words (None = no filter).
            min_bigram_freq: Drop bigram contexts with total count below this.
            min_trigram_freq: Drop trigram contexts with total count below this.
            max_bigram_contexts: Keep at most this many bigram contexts (by frequency).
            max_trigram_contexts: Keep at most this many trigram contexts (by frequency).
            max_starters: Keep at most this many sentence starters.
            max_enders: Keep at most this many sentence enders.
        """
        # Optional vocab filtering
        if vocab_filter:
            print(f"  Filtering against vocabulary of {len(vocab_filter):,} words …")

        def ok(w: str) -> bool:
            if is_sentence_end(w):
                return True
            if not is_clean(w):
                return False
            if vocab_filter and w not in vocab_filter and len(w) > 1:
                return False
            return True

        # Build bigram model (prune by frequency, cap total contexts)
        bigrams_raw = {}
        for w1, followers in self.bigram_counts.items():
            if not ok(w1):
                continue
            filtered = Counter({w2: c for w2, c in followers.items() if ok(w2)})
            total = sum(filtered.values())
            if filtered and total >= min_bigram_freq:
                bigrams_raw[(w1, total)] = filtered

        # Keep top contexts by frequency
        sorted_bi = sorted(bigrams_raw.items(), key=lambda x: x[0][1], reverse=True)
        if len(sorted_bi) > max_bigram_contexts:
            sorted_bi = sorted_bi[:max_bigram_contexts]

        bigrams = {}
        for (w1, _total), filtered in sorted_bi:
            bigrams[w1] = self._normalise(filtered, top_k=15)
        print(f"  Bigram contexts: {len(bigrams):,}")

        # Build trigram model (prune by frequency, cap total contexts)
        trigrams_raw = {}
        for (w1, w2), followers in self.trigram_counts.items():
            if not ok(w1) or not ok(w2):
                continue
            filtered = Counter({w3: c for w3, c in followers.items() if ok(w3)})
            total = sum(filtered.values())
            if filtered and total >= min_trigram_freq:
                key = f"{w1} {w2}"
                trigrams_raw[(key, total)] = filtered

        sorted_tri = sorted(trigrams_raw.items(), key=lambda x: x[0][1], reverse=True)
        if len(sorted_tri) > max_trigram_contexts:
            sorted_tri = sorted_tri[:max_trigram_contexts]

        trigrams = {}
        for (key, _total), filtered in sorted_tri:
            trigrams[key] = self._normalise(filtered, top_k=10)
        print(f"  Trigram contexts: {len(trigrams):,}")

        # Build starters — collect many, then filter
        starter_list = []
        for (w1, w2), count in self.starters.most_common(max_starters * 5):
            if ok(w1) and ok(w2):
                starter_list.append([w1, w2, count])
            if len(starter_list) >= max_starters:
                break
        total_s = sum(s[2] for s in starter_list) if starter_list else 1
        starters = [[s[0], s[1], round(s[2] / total_s, 6)] for s in starter_list]
        print(f"  Sentence starters: {len(starters)}")

        # Build enders
        ender_items = []
        for w, c in self.enders.most_common(max_enders * 5):
            if ok(w):
                ender_items.append((w, c))
            if len(ender_items) >= max_enders:
                break
        total_e = sum(c for _, c in ender_items) if ender_items else 1
        enders = [[w, round(c / total_e, 6)] for w, c in ender_items]
        print(f"  Sentence enders: {len(enders)}")

        # Vocab stats
        vocab_total = len(self.vocab)
        tier_counts = Counter(self.word_tiers.values())

        meta = {
            "starters": starters,
            "enders": enders,
            "vocab_size": vocab_total,
            "tier_counts": {str(k): v for k, v in sorted(tier_counts.items())},
            "word_tiers": {w: t for w, t in sorted(self.word_tiers.items())
                          if ok(w)},
        }

        return {
            "bigrams": bigrams,
            "trigrams": trigrams,
            "meta": meta,
        }


# ---------------------------------------------------------------------------
# Vocabulary loading
# ---------------------------------------------------------------------------

def load_vocab_filter(assets_dir: str) -> set[str] | None:
    """Try to load vocabulary from tier JSON files or common word list."""
    vocab = set()
    assets = Path(assets_dir)

    # Try tier files first
    tier_files = sorted(assets.glob("dictionaries/tier*.json"))
    # Exclude metadata files
    tier_files = [f for f in tier_files if "meta" not in f.name]
    if tier_files:
        for tf in tier_files:
            try:
                with open(tf, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if isinstance(data, dict) and "words" in data:
                    # Format: {"words": [{"word": "...", ...}, ...]}
                    for entry in data["words"]:
                        if isinstance(entry, dict) and "word" in entry:
                            vocab.add(entry["word"].lower())
                        elif isinstance(entry, str):
                            vocab.add(entry.lower())
                elif isinstance(data, list):
                    vocab.update(w.lower() for w in data if isinstance(w, str))
            except Exception as e:
                print(f"  Warning: could not load {tf}: {e}")
        if vocab:
            print(f"  Loaded {len(vocab):,} words from tier dictionaries")
            return vocab

    # Try common word list
    common = assets / "dictionaries" / "nb_common_500.json"
    if common.exists():
        try:
            with open(common, "r", encoding="utf-8") as f:
                words = json.load(f)
            if isinstance(words, list):
                vocab.update(w.lower() for w in words if isinstance(w, str))
                print(f"  Loaded {len(vocab):,} words from {common.name}")
                # For a small vocab list, don't use as strict filter — just
                # return None so all corpus words pass
                print("  (word list too small for strict filtering, skipping filter)")
                return None
        except Exception as e:
            print(f"  Warning: could not load {common}: {e}")

    print("  No dictionary files found; skipping vocabulary filter")
    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Build Markov chain model for Norwegian sentence generation"
    )
    parser.add_argument(
        "--ngram-dir",
        help="Path to extracted NB N-gram corpus directory",
    )
    parser.add_argument(
        "--bootstrap",
        action="store_true",
        help="Include curated sentence corpus (can combine with --ngram-dir)",
    )
    parser.add_argument(
        "--output", "-o",
        required=True,
        help="Output directory for model JSON files",
    )
    parser.add_argument(
        "--assets-dir",
        default=None,
        help="Path to assets directory (for vocabulary filter). "
             "Defaults to ../../assets/ relative to this script.",
    )
    parser.add_argument(
        "--min-bigram-freq", type=int, default=50,
        help="Drop bigram contexts with total count below this (default: 50)",
    )
    parser.add_argument(
        "--min-trigram-freq", type=int, default=20,
        help="Drop trigram contexts with total count below this (default: 20)",
    )
    parser.add_argument(
        "--max-bigram-contexts", type=int, default=3000,
        help="Keep at most this many bigram contexts (default: 3000)",
    )
    parser.add_argument(
        "--max-trigram-contexts", type=int, default=5000,
        help="Keep at most this many trigram contexts (default: 5000)",
    )
    args = parser.parse_args()

    # Resolve assets dir
    if args.assets_dir:
        assets_dir = args.assets_dir
    else:
        script_dir = Path(__file__).resolve().parent
        assets_dir = str(script_dir / ".." / ".." / "assets")

    # Ensure output directory exists
    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not args.bootstrap and not args.ngram_dir:
        parser.error("Provide at least one of --bootstrap or --ngram-dir")

    builder = MarkovModelBuilder()

    if args.bootstrap:
        print("=== Bootstrap mode: building from curated sentences ===")
        sentences_by_tier = get_all_sentences()
        total = 0
        for tier, sentences in sorted(sentences_by_tier.items()):
            print(f"  Tier {tier}: {len(sentences)} sentences")
            for s in sentences:
                builder.add_sentence(s, weight=1, tier=tier)
            total += len(sentences)
        print(f"  Total: {total} sentences")

    if args.ngram_dir:
        print(f"=== NB corpus mode: reading from {args.ngram_dir} ===")
        ngram_path = Path(args.ngram_dir)
        if not ngram_path.is_dir():
            print(f"Error: {args.ngram_dir} is not a directory", file=sys.stderr)
            sys.exit(1)

        # Look for 2-gram and 3-gram files
        for n in (2, 3):
            candidates = [
                ngram_path / f"{n}-gram.txt",
                ngram_path / f"{n}gram.txt",
                ngram_path / f"{n}-grams.txt",
            ]
            found = None
            for c in candidates:
                if c.exists():
                    found = c
                    break
            if found is None:
                # Try glob
                matches = list(ngram_path.glob(f"*{n}*gram*"))
                if matches:
                    found = matches[0]

            if found:
                print(f"  Loading {n}-grams from {found} …")
                builder.add_ngram_file(str(found), n)
            else:
                print(f"  Warning: no {n}-gram file found in {args.ngram_dir}")

    # Load optional vocabulary filter
    print("\n--- Loading vocabulary filter ---")
    vocab_filter = load_vocab_filter(assets_dir)

    # Build the model
    print("\n--- Building model ---")
    model = builder.build(
        vocab_filter=vocab_filter,
        min_bigram_freq=args.min_bigram_freq,
        min_trigram_freq=args.min_trigram_freq,
        max_bigram_contexts=args.max_bigram_contexts,
        max_trigram_contexts=args.max_trigram_contexts,
    )

    # Write output files
    print("\n--- Writing output ---")

    bigram_path = out_dir / "markov_bigrams.json"
    with open(bigram_path, "w", encoding="utf-8") as f:
        json.dump(model["bigrams"], f, ensure_ascii=False, separators=(",", ":"))
    size_b = bigram_path.stat().st_size
    print(f"  {bigram_path} ({size_b:,} bytes)")

    trigram_path = out_dir / "markov_trigrams.json"
    with open(trigram_path, "w", encoding="utf-8") as f:
        json.dump(model["trigrams"], f, ensure_ascii=False, separators=(",", ":"))
    size_t = trigram_path.stat().st_size
    print(f"  {trigram_path} ({size_t:,} bytes)")

    meta_path = out_dir / "markov_meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(model["meta"], f, ensure_ascii=False, separators=(",", ":"))
    size_m = meta_path.stat().st_size
    print(f"  {meta_path} ({size_m:,} bytes)")

    # Quick sanity check: generate a few sample sentences
    print("\n--- Sample sentences (sanity check) ---")
    import random
    random.seed(42)
    for _ in range(5):
        sent = generate_sample(model)
        print(f"  → {sent}")

    print("\nDone ✓")


def generate_sample(model: dict, max_len: int = 20) -> str:
    """Generate a single sample sentence from the model (for sanity checking)."""
    import random

    starters = model["meta"]["starters"]
    enders = set(e[0] for e in model["meta"]["enders"])
    trigrams = model["trigrams"]
    bigrams = model["bigrams"]

    if not starters:
        return "(no starters)"

    # Pick a starter weighted by probability
    r = random.random()
    cumulative = 0.0
    w1, w2 = starters[0][0], starters[0][1]
    for s in starters:
        cumulative += s[2]
        if r <= cumulative:
            w1, w2 = s[0], s[1]
            break

    words = [w1, w2]

    for _ in range(max_len):
        key = f"{words[-2]} {words[-1]}"
        candidates = trigrams.get(key)
        if not candidates:
            # Fall back to bigrams
            candidates = bigrams.get(words[-1])
        if not candidates:
            break

        # Weighted random selection
        r = random.random()
        cumulative = 0.0
        chosen = candidates[0][0]
        for tok, prob in candidates:
            cumulative += prob
            if r <= cumulative:
                chosen = tok
                break

        if chosen in (".", "!", "?"):
            break

        words.append(chosen)

        # Stop if we hit an ender and sentence is long enough
        if len(words) >= 8 and chosen in enders:
            if random.random() < 0.3:
                break

    # Capitalise first word, add period
    if words:
        words[0] = words[0].capitalize()
    return " ".join(words) + "."


if __name__ == "__main__":
    main()
