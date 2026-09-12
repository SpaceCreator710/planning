import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum IconEngine {
    private struct Rule {
        let terms: [String]
        let symbol: String
        let fallback: String
        let color: TaskColor
    }

    // Order matters: specific school, hygiene and sport phrases come before broad categories.
    private static let rules: [Rule] = [
        // Hygiene & personal care
        Rule(terms: ["shower", "take a shower", "душ", "в душ", "помыться", "мыться"], symbol: "shower.fill", fallback: "drop.fill", color: .teal),
        Rule(terms: ["brush teeth", "toothbrush", "teeth", "почистить зуб", "зубы"], symbol: "mouth.fill", fallback: "cross.case.fill", color: .teal),
        Rule(terms: ["wash face", "skincare", "skin care", "умыться", "уход за кож"], symbol: "face.smiling", fallback: "drop.fill", color: .pink),
        Rule(terms: ["haircut", "barber", "парикмах", "стрижк"], symbol: "scissors", fallback: "person.crop.circle", color: .violet),
        Rule(terms: ["bath", "take a bath", "ванна", "принять ванну"], symbol: "bathtub.fill", fallback: "drop.fill", color: .teal),
        Rule(terms: ["shave", "shaving", "бриться", "бритье", "бритьё"], symbol: "mustache.fill", fallback: "scissors", color: .gray),
        Rule(terms: ["makeup", "make up", "макияж", "накраситься"], symbol: "paintbrush.pointed.fill", fallback: "face.smiling", color: .pink),
        Rule(terms: ["nails", "manicure", "pedicure", "ногти", "маникюр", "педикюр"], symbol: "hand.raised.fill", fallback: "sparkles", color: .pink),
        Rule(terms: ["get dressed", "dress up", "change clothes", "одеться", "переодеться"], symbol: "tshirt.fill", fallback: "person.fill", color: .violet),
        Rule(terms: ["deodorant", "perfume", "cologne", "духи", "дезодорант"], symbol: "spraybottle.fill", fallback: "sparkles", color: .pink),

        // School subjects
        // School commute comes before the broad "school" rule.
        Rule(terms: ["school bus", "автобус в школу"], symbol: "bus.fill", fallback: "backpack.fill", color: .orange),
        Rule(terms: ["go to school", "to school", "school commute", "в школу", "идти в школу", "дорога в школу"], symbol: "backpack.fill", fallback: "graduationcap.fill", color: .indigo),

        Rule(terms: ["algebra", "math", "mathematics", "матем", "алгебр"], symbol: "function", fallback: "plus.forwardslash.minus", color: .indigo),
        Rule(terms: ["calculus", "trigonometry", "statistics", "probability", "исчислен", "тригонометр", "статистик", "вероятност"], symbol: "function", fallback: "plus.forwardslash.minus", color: .indigo),
        Rule(terms: ["russian language", "русский язык", "рус яз", "русский"], symbol: "textformat", fallback: "character.book.closed.fill", color: .indigo),
        Rule(terms: ["technology class", "woodwork", "craft class", "технология", "труд"], symbol: "hammer.fill", fallback: "wrench.and.screwdriver.fill", color: .orange),
        Rule(terms: ["life safety", "safety class", "обж", "основы безопасности"], symbol: "shield.fill", fallback: "cross.case.fill", color: .orange),
        Rule(terms: ["science", "естествозн"], symbol: "atom", fallback: "flask.fill", color: .teal),
        Rule(terms: ["geometry", "геометр"], symbol: "triangle", fallback: "ruler", color: .indigo),
        Rule(terms: ["physics", "физик"], symbol: "atom", fallback: "waveform", color: .blue),
        Rule(terms: ["chemistry", "chemical", "хими"], symbol: "flask.fill", fallback: "drop.triangle.fill", color: .teal),
        Rule(terms: ["biology", "биолог"], symbol: "microbe.fill", fallback: "leaf.fill", color: .green),
        Rule(terms: ["history", "истори"], symbol: "building.columns.fill", fallback: "books.vertical.fill", color: .orange),
        Rule(terms: ["geography", "географ"], symbol: "globe.europe.africa.fill", fallback: "globe", color: .blue),
        Rule(terms: ["literature", "литератур"], symbol: "books.vertical.fill", fallback: "book.closed.fill", color: .violet),
        Rule(terms: ["english", "spanish", "french", "german", "language", "англий", "испан", "француз", "немец", "язык"], symbol: "character.book.closed.fill", fallback: "text.book.closed.fill", color: .indigo),
        Rule(terms: ["computer science", "informatics", "информат", "программирован"], symbol: "laptopcomputer", fallback: "desktopcomputer", color: .blue),
        Rule(terms: ["art class", "drawing class", "изо", "рисован"], symbol: "paintpalette.fill", fallback: "paintbrush.fill", color: .pink),
        Rule(terms: ["music class", "музыка"], symbol: "music.note", fallback: "headphones", color: .violet),
        Rule(terms: ["physical education", "pe class", "физкультур", "физра"], symbol: "figure.run", fallback: "dumbbell.fill", color: .green),
        Rule(terms: ["astronomy", "астроном"], symbol: "sparkles", fallback: "moon.stars.fill", color: .indigo),
        Rule(terms: ["economics", "economy", "экономик"], symbol: "chart.line.uptrend.xyaxis", fallback: "chart.bar.fill", color: .green),
        Rule(terms: ["social studies", "civics", "общество", "обществозн"], symbol: "person.3.fill", fallback: "person.2.fill", color: .orange),
        Rule(terms: ["law", "legal", "право"], symbol: "scalemass.fill", fallback: "building.columns.fill", color: .blue),
        Rule(terms: ["philosophy", "философ"], symbol: "brain.head.profile", fallback: "brain", color: .violet),
        Rule(terms: ["ecology", "environment", "эколог"], symbol: "leaf.circle.fill", fallback: "leaf.fill", color: .green),
        Rule(terms: ["robotics", "robot", "робот"], symbol: "gearshape.2.fill", fallback: "cpu.fill", color: .blue),
        Rule(terms: ["engineering", "engineer", "инженер"], symbol: "wrench.and.screwdriver.fill", fallback: "hammer.fill", color: .orange),
        Rule(terms: ["unit test", "ui test", "integration test", "test app", "software test", "quality assurance", "qa check", "qa", "тест приложения", "тестировать код"], symbol: "checkmark.seal.fill", fallback: "ladybug.fill", color: .green),
        Rule(terms: ["quiz", "school test", "practice test", "mock exam", "тест по", "викторина", "пробник"], symbol: "checklist", fallback: "graduationcap.fill", color: .indigo),
        Rule(terms: ["assignment", "coursework", "worksheet", "задание по", "учебное задание"], symbol: "doc.text.fill", fallback: "pencil.line", color: .indigo),
        Rule(terms: ["flashcards", "flash cards", "карточки", "флешкарты"], symbol: "rectangle.stack.fill", fallback: "books.vertical.fill", color: .violet),
        Rule(terms: ["take notes", "class notes", "lecture notes", "конспект", "записать конспект"], symbol: "note.text", fallback: "square.and.pencil", color: .indigo),
        Rule(terms: ["revise", "revision", "review notes", "повторить материал", "повторение"], symbol: "arrow.triangle.2.circlepath", fallback: "book.closed.fill", color: .indigo),
        Rule(terms: ["library", "библиотека"], symbol: "books.vertical.fill", fallback: "building.columns.fill", color: .violet),
        Rule(terms: ["lecture", "seminar", "webinar", "лекция", "семинар", "вебинар"], symbol: "person.wave.2.fill", fallback: "graduationcap.fill", color: .indigo),
        Rule(terms: ["tutor", "tutoring", "private lesson", "репетитор", "занятие с репетитором"], symbol: "person.2.fill", fallback: "graduationcap.fill", color: .indigo),
        Rule(terms: ["laboratory", "lab work", "lab class", "лабораторная", "лаба"], symbol: "flask.fill", fallback: "atom", color: .teal),
        Rule(terms: ["memorize", "memorise", "learn by heart", "выучить наизусть", "запомнить"], symbol: "brain.fill", fallback: "brain", color: .violet),
        Rule(terms: ["language practice", "vocabulary", "speaking practice", "словарь", "слова на английском", "практика языка"], symbol: "character.book.closed.fill", fallback: "textformat", color: .indigo),
        Rule(terms: ["school", "study", "homework", "exam", "lesson", "class", "learn", "учеб", "школ", "урок", "домашн", "дз", "экзамен", "контрольн"], symbol: "graduationcap.fill", fallback: "book.closed.fill", color: .indigo),

        // Fun, rest & everyday mood
        Rule(terms: ["have fun", "fun time", "fun", "enjoy", "развлеч", "повеселиться", "весель"], symbol: "face.smiling.fill", fallback: "party.popper.fill", color: .pink),
        Rule(terms: ["chill", "chill out", "take it easy", "unwind", "расслабиться", "чилл", "отдохнуть"], symbol: "sparkles", fallback: "leaf.fill", color: .teal),
        Rule(terms: ["hang out", "hangout", "friends", "meet friends", "social", "друзья", "с друзьями", "пообщаться"], symbol: "person.2.fill", fallback: "bubble.left.and.bubble.right.fill", color: .pink),
        Rule(terms: ["family time", "family", "семья", "с семьей", "с семьёй"], symbol: "person.3.fill", fallback: "house.fill", color: .orange),

        // Sports & movement
        Rule(terms: ["workout", "training", "gym", "strength", "fitness", "exercise", "трениров", "спортзал", "фитнес", "силов"], symbol: "dumbbell.fill", fallback: "figure.strengthtraining.traditional", color: .green),
        Rule(terms: ["football", "soccer", "футбол"], symbol: "figure.soccer", fallback: "soccerball", color: .green),
        Rule(terms: ["basketball", "баскетбол"], symbol: "figure.basketball", fallback: "basketball.fill", color: .orange),
        Rule(terms: ["volleyball", "волейбол"], symbol: "figure.volleyball", fallback: "figure.play", color: .blue),
        Rule(terms: ["tennis", "теннис"], symbol: "figure.tennis", fallback: "tennis.racket", color: .green),
        Rule(terms: ["hockey", "хоккей"], symbol: "figure.hockey", fallback: "figure.skating", color: .blue),
        Rule(terms: ["boxing", "бокс"], symbol: "figure.boxing", fallback: "figure.strengthtraining.traditional", color: .red),
        Rule(terms: ["martial arts", "karate", "taekwondo", "единобор", "карат", "тхэквондо"], symbol: "figure.kickboxing", fallback: "figure.strengthtraining.functional", color: .red),
        Rule(terms: ["yoga", "йога"], symbol: "figure.yoga", fallback: "figure.mind.and.body", color: .teal),
        Rule(terms: ["pilates", "пилатес"], symbol: "figure.pilates", fallback: "figure.core.training", color: .teal),
        Rule(terms: ["crossfit", "cross training", "кроссфит"], symbol: "figure.cross.training", fallback: "dumbbell.fill", color: .green),
        Rule(terms: ["wrestling", "борьба"], symbol: "figure.wrestling", fallback: "figure.martial.arts", color: .red),
        Rule(terms: ["cricket", "крикет"], symbol: "figure.cricket", fallback: "sportscourt.fill", color: .green),
        Rule(terms: ["lacrosse", "лакросс"], symbol: "figure.lacrosse", fallback: "sportscourt.fill", color: .green),
        Rule(terms: ["pickleball", "пиклбол"], symbol: "figure.pickleball", fallback: "tennis.racket", color: .green),
        Rule(terms: ["jump rope", "skipping rope", "скакалк"], symbol: "figure.jumprope", fallback: "figure.run", color: .orange),
        Rule(terms: ["sailing", "парус", "яхт"], symbol: "figure.sailing", fallback: "water.waves", color: .teal),
        Rule(terms: ["fishing", "рыбал", "рыбач"], symbol: "figure.fishing", fallback: "water.waves", color: .teal),
        Rule(terms: ["horse riding", "equestrian", "верховая езда", "конный спорт"], symbol: "figure.equestrian.sports", fallback: "figure.walk", color: .orange),
        Rule(terms: ["dance", "dancing", "танц"], symbol: "figure.dance", fallback: "music.note", color: .pink),
        Rule(terms: ["gymnastics", "гимнаст"], symbol: "figure.gymnastics", fallback: "figure.flexibility", color: .violet),
        Rule(terms: ["swim", "pool", "плав", "бассейн"], symbol: "figure.pool.swim", fallback: "water.waves", color: .teal),
        Rule(terms: ["ski", "skiing", "лыж"], symbol: "figure.skiing.downhill", fallback: "figure.snowboarding", color: .blue),
        Rule(terms: ["skate", "skating", "коньк"], symbol: "figure.skating", fallback: "figure.snowboarding", color: .blue),
        Rule(terms: ["run", "jog", "running", "бег", "пробеж"], symbol: "figure.run", fallback: "figure.walk", color: .green),
        Rule(terms: ["walk", "steps", "walking", "ходь", "прогул"], symbol: "figure.walk", fallback: "shoe", color: .green),
        Rule(terms: ["bike", "cycling", "cycle", "велосип"], symbol: "bicycle", fallback: "figure.outdoor.cycle", color: .green),
        Rule(terms: ["hike", "hiking", "поход"], symbol: "figure.hiking", fallback: "mountain.2.fill", color: .green),
        Rule(terms: ["badminton", "бадминтон"], symbol: "figure.badminton", fallback: "sportscourt.fill", color: .green),
        Rule(terms: ["table tennis", "ping pong", "настольный теннис", "пинг понг", "пинг-понг"], symbol: "figure.table.tennis", fallback: "tennis.racket", color: .orange),
        Rule(terms: ["baseball", "бейсбол"], symbol: "figure.baseball", fallback: "baseball.fill", color: .orange),
        Rule(terms: ["rugby", "регби"], symbol: "figure.rugby", fallback: "sportscourt.fill", color: .green),
        Rule(terms: ["handball", "гандбол"], symbol: "figure.handball", fallback: "sportscourt.fill", color: .blue),
        Rule(terms: ["climb", "climbing", "скалолаз"], symbol: "figure.climbing", fallback: "mountain.2.fill", color: .orange),
        Rule(terms: ["row", "rowing", "гребл"], symbol: "figure.rower", fallback: "water.waves", color: .teal),
        Rule(terms: ["surf", "surfing", "серф"], symbol: "figure.surfing", fallback: "water.waves", color: .teal),
        Rule(terms: ["snowboard", "snowboarding", "сноуборд"], symbol: "figure.snowboarding", fallback: "snowflake", color: .blue),
        Rule(terms: ["archery", "стрельба из лука", "лук"], symbol: "scope", fallback: "target", color: .red),
        Rule(terms: ["fencing", "фехтован"], symbol: "figure.fencing", fallback: "figure.martial.arts", color: .red),
        Rule(terms: ["golf", "гольф"], symbol: "figure.golf", fallback: "flag.fill", color: .green),
        Rule(terms: ["skateboard", "skateboarding", "скейтборд"], symbol: "figure.skateboarding", fallback: "figure.outdoor.cycle", color: .violet),
        Rule(terms: ["stretch", "stretching", "растяжка", "разминка"], symbol: "figure.flexibility", fallback: "figure.cooldown", color: .teal),
        Rule(terms: ["cooldown", "cool down", "заминка"], symbol: "figure.cooldown", fallback: "figure.walk", color: .teal),
        Rule(terms: ["warmup", "warm up", "warm-up", "разогрев"], symbol: "figure.run", fallback: "flame.fill", color: .orange),
        Rule(terms: ["elliptical", "эллипс"], symbol: "figure.elliptical", fallback: "figure.run", color: .green),
        Rule(terms: ["stair stepper", "stairs workout", "степпер"], symbol: "figure.stair.stepper", fallback: "figure.stairs", color: .green),
        Rule(terms: ["tai chi", "taichi", "тайцзи"], symbol: "figure.taichi", fallback: "figure.mind.and.body", color: .teal),
        Rule(terms: ["water polo", "waterpolo", "водное поло"], symbol: "figure.waterpolo", fallback: "water.waves", color: .blue),
        Rule(terms: ["track and field", "athletics", "легкая атлетика", "лёгкая атлетика"], symbol: "figure.track.and.field", fallback: "figure.run", color: .green),

        // Transport. The workout rule above catches "training" first; the exact token "train" remains a railway train.
        Rule(terms: ["train"], symbol: "train.side.front.car", fallback: "tram.fill", color: .indigo),
        Rule(terms: ["train station", "railway", "rail trip", "train to", "train from", "поезд", "электрич", "вокзал"], symbol: "tram.fill", fallback: "train.side.front.car", color: .indigo),
        Rule(terms: ["commute", "commuting", "get to work", "get to school", "дорога на работу", "дорога"], symbol: "car.fill", fallback: "bus.fill", color: .blue),
        Rule(terms: ["boat", "ferry", "ship", "паром", "кораб", "лодк"], symbol: "ferry.fill", fallback: "water.waves", color: .teal),
        Rule(terms: ["metro", "subway", "метро"], symbol: "tram.fill", fallback: "bus.fill", color: .indigo),
        Rule(terms: ["gas", "fuel", "gas station", "fill up car", "заправка", "бензин", "топливо"], symbol: "fuelpump.fill", fallback: "car.fill", color: .orange),
        Rule(terms: ["parking", "park car", "парковка", "припарковаться"], symbol: "parkingsign.circle.fill", fallback: "car.fill", color: .blue),
        Rule(terms: ["car wash", "wash car", "мойка машины", "помыть машину"], symbol: "car.side.fill", fallback: "drop.fill", color: .teal),
        Rule(terms: ["car service", "mechanic", "oil change", "service car", "автосервис", "механик", "замена масла"], symbol: "wrench.and.screwdriver.fill", fallback: "car.fill", color: .orange),
        Rule(terms: ["car", "drive", "road trip", "uber", "taxi", "машин", "такси", "за рул"], symbol: "car.fill", fallback: "car", color: .blue),
        Rule(terms: ["bus", "автобус"], symbol: "bus.fill", fallback: "bus", color: .orange),
        Rule(terms: ["flight", "airport", "plane", "airplane", "самолет", "самолёт", "аэропорт"], symbol: "airplane", fallback: "airplane", color: .blue),
        Rule(terms: ["hotel", "check in hotel", "check-in hotel", "гостиница", "отель"], symbol: "building.2.fill", fallback: "bed.double.fill", color: .orange),
        Rule(terms: ["check in", "check-in", "boarding", "boarding pass", "регистрация на рейс", "посадочный"], symbol: "checkmark.circle.fill", fallback: "airplane", color: .blue),
        Rule(terms: ["passport", "visa", "паспорт", "виза"], symbol: "person.text.rectangle.fill", fallback: "doc.text.fill", color: .blue),
        Rule(terms: ["luggage", "baggage", "suitcase", "багаж", "чемодан"], symbol: "suitcase.rolling.fill", fallback: "suitcase.fill", color: .orange),
        Rule(terms: ["directions", "route", "navigate", "маршрут", "навигация"], symbol: "map.fill", fallback: "location.fill", color: .blue),
        Rule(terms: ["travel", "trip", "путеше", "поездка"], symbol: "suitcase.fill", fallback: "map.fill", color: .orange),

        // Work & creativity
        Rule(terms: ["project", "project work", "проект"], symbol: "folder.fill", fallback: "list.clipboard.fill", color: .blue),
        Rule(terms: ["deadline", "due date", "срок", "дедлайн"], symbol: "calendar.badge.exclamationmark", fallback: "exclamationmark.triangle.fill", color: .red),
        Rule(terms: ["interview", "job interview", "собеседован"], symbol: "person.crop.rectangle.badge.plus", fallback: "briefcase.fill", color: .blue),
        Rule(terms: ["research", "researching", "исследован"], symbol: "magnifyingglass", fallback: "book.closed.fill", color: .indigo),
        Rule(terms: ["admin", "paperwork", "forms", "бумаги", "документы"], symbol: "list.clipboard.fill", fallback: "doc.text.fill", color: .gray),
        Rule(terms: ["read", "book", "reading", "читать", "книга", "чтение"], symbol: "books.vertical.fill", fallback: "book.fill", color: .violet),
        Rule(terms: ["code", "coding", "developer", "build app", "develop app", "app development", "код", "разработ"], symbol: "chevron.left.forwardslash.chevron.right", fallback: "laptopcomputer", color: .indigo),
        Rule(terms: ["design", "figma", "draw", "sketch", "дизайн", "рисов"], symbol: "paintbrush.fill", fallback: "pencil", color: .violet),
        Rule(terms: ["presentation", "slides", "deck", "презентац", "слайды"], symbol: "rectangle.3.group.fill", fallback: "display", color: .violet),
        Rule(terms: ["write", "essay", "draft", "писать", "сочинен", "реферат"], symbol: "pencil.line", fallback: "square.and.pencil", color: .indigo),
        Rule(terms: ["video call", "zoom call", "google meet", "facetime", "teams call", "видеозвонок", "зум"], symbol: "video.fill", fallback: "video", color: .blue),
        Rule(terms: ["standup", "stand up meeting", "daily sync", "daily meeting", "стендап", "дейли"], symbol: "person.3.fill", fallback: "person.2.fill", color: .blue),
        Rule(terms: ["one on one", "one-on-one", "1 on 1", "1:1", "ван ту ван"], symbol: "person.2.fill", fallback: "bubble.left.and.bubble.right.fill", color: .blue),
        Rule(terms: ["debug", "debugging", "bug fix", "fix bug", "исправить баг", "дебаг"], symbol: "ladybug.fill", fallback: "wrench.and.screwdriver.fill", color: .red),
        Rule(terms: ["deploy", "deployment", "ship build", "релизнуть", "деплой"], symbol: "arrow.up.circle.fill", fallback: "paperplane.fill", color: .green),
        Rule(terms: ["release", "app release", "publish app", "релиз", "публикация приложения"], symbol: "rocket.fill", fallback: "paperplane.fill", color: .green),
        Rule(terms: ["spreadsheet", "excel", "numbers sheet", "таблица", "эксель"], symbol: "tablecells.fill", fallback: "list.clipboard.fill", color: .green),
        Rule(terms: ["analytics", "metrics", "dashboard", "kpi", "аналитика", "метрики"], symbol: "chart.bar.xaxis", fallback: "chart.bar.fill", color: .green),
        Rule(terms: ["invoice", "receipt", "expense", "счет", "счёт", "чек", "расходы"], symbol: "doc.text.fill", fallback: "creditcard.fill", color: .green),
        Rule(terms: ["tax", "taxes", "налоги", "налог"], symbol: "dollarsign.circle.fill", fallback: "banknote.fill", color: .green),
        Rule(terms: ["contract", "agreement", "sign document", "договор", "контракт", "подписать документ"], symbol: "signature", fallback: "doc.text.fill", color: .blue),
        Rule(terms: ["scan", "scan document", "скан", "отсканировать"], symbol: "doc.viewfinder", fallback: "camera.fill", color: .blue),
        Rule(terms: ["print", "print document", "распечатать", "печать"], symbol: "printer.fill", fallback: "printer", color: .gray),
        Rule(terms: ["upload", "upload file", "загрузить файл", "аплоад"], symbol: "arrow.up.doc.fill", fallback: "icloud.and.arrow.up.fill", color: .blue),
        Rule(terms: ["download", "download file", "скачать", "загрузка файла"], symbol: "arrow.down.circle.fill", fallback: "tray.and.arrow.down.fill", color: .blue),
        Rule(terms: ["backup", "back up", "резервная копия", "бэкап"], symbol: "externaldrive.fill.badge.timemachine", fallback: "externaldrive.fill", color: .blue),
        Rule(terms: ["organize files", "sort files", "clean files", "разобрать файлы", "организовать файлы"], symbol: "folder.fill", fallback: "archivebox.fill", color: .blue),
        Rule(terms: ["record podcast", "podcast", "record audio", "voice recording", "подкаст", "записать аудио"], symbol: "mic.fill", fallback: "waveform", color: .violet),
        Rule(terms: ["edit video", "video edit", "монтаж видео", "смонтировать видео"], symbol: "film.stack.fill", fallback: "film.fill", color: .violet),
        Rule(terms: ["edit photo", "photo edit", "retouch", "обработать фото", "ретушь"], symbol: "photo.on.rectangle.angled", fallback: "photo.fill", color: .pink),
        Rule(terms: ["marketing", "campaign", "реклама", "маркетинг"], symbol: "megaphone.fill", fallback: "chart.line.uptrend.xyaxis", color: .orange),
        Rule(terms: ["sales", "sales call", "продажи"], symbol: "chart.line.uptrend.xyaxis", fallback: "briefcase.fill", color: .green),
        Rule(terms: ["customer support", "support ticket", "client support", "поддержка клиента", "тикет"], symbol: "headphones", fallback: "bubble.left.and.bubble.right.fill", color: .blue),
        Rule(terms: ["networking", "network event", "нетворкинг"], symbol: "person.3.fill", fallback: "link", color: .blue),
        Rule(terms: ["resume", "cv", "curriculum vitae", "резюме"], symbol: "person.text.rectangle.fill", fallback: "doc.text.fill", color: .blue),
        Rule(terms: ["portfolio", "портфолио"], symbol: "rectangle.stack.fill", fallback: "briefcase.fill", color: .violet),
        Rule(terms: ["email", "e-mail", "send email", "check email", "почта", "письмо"], symbol: "envelope.fill", fallback: "mail.fill", color: .blue),
        Rule(terms: ["meeting", "team", "call with", "встреч", "команд"], symbol: "person.2.fill", fallback: "person.2", color: .blue),
        Rule(terms: ["call", "phone", "звон", "телефон"], symbol: "phone.fill", fallback: "phone", color: .green),
        Rule(terms: ["message", "text", "reply", "dm", "сообщ", "ответить", "написать"], symbol: "bubble.left.and.bubble.right.fill", fallback: "message.fill", color: .blue),
        Rule(terms: ["work", "working", "office", "job", "shift", "работа", "работать", "офис", "смена"], symbol: "briefcase.fill", fallback: "laptopcomputer", color: .blue),

        // Daily life
        Rule(terms: ["pharmacy", "drugstore", "аптека"], symbol: "cross.case.fill", fallback: "pill.fill", color: .red),
        Rule(terms: ["package pickup", "pick up package", "parcel pickup", "забрать посылку", "получить посылку"], symbol: "shippingbox.fill", fallback: "tray.and.arrow.down.fill", color: .orange),
        Rule(terms: ["delivery", "deliver package", "courier", "доставка", "курьер"], symbol: "truck.box.fill", fallback: "shippingbox.fill", color: .orange),
        Rule(terms: ["post office", "mail package", "send package", "почта россии", "отправить посылку"], symbol: "envelope.fill", fallback: "shippingbox.fill", color: .blue),
        Rule(terms: ["take out trash", "trash", "garbage", "выбросить мусор", "мусор"], symbol: "trash.fill", fallback: "delete.left.fill", color: .gray),
        Rule(terms: ["recycle", "recycling", "переработка", "сортировать мусор"], symbol: "arrow.3.trianglepath", fallback: "leaf.fill", color: .green),
        Rule(terms: ["wash clothes", "washing machine", "laundry load", "постирать", "стиральная машина"], symbol: "washer.fill", fallback: "bubbles.and.sparkles.fill", color: .teal),
        Rule(terms: ["fold clothes", "fold laundry", "сложить одежду", "сложить белье", "сложить бельё"], symbol: "tshirt.fill", fallback: "square.stack.3d.up.fill", color: .violet),
        Rule(terms: ["iron clothes", "ironing", "гладить", "погладить одежду"], symbol: "tshirt.fill", fallback: "sparkles", color: .violet),
        Rule(terms: ["make bed", "заправить кровать"], symbol: "bed.double.fill", fallback: "house.fill", color: .indigo),
        Rule(terms: ["clean bathroom", "bathroom clean", "убрать ванную", "уборка ванной"], symbol: "toilet.fill", fallback: "sparkles", color: .teal),
        Rule(terms: ["clean kitchen", "kitchen clean", "убрать кухню", "уборка кухни"], symbol: "sink.fill", fallback: "sparkles", color: .teal),
        Rule(terms: ["clean room", "room clean", "убрать комнату", "уборка комнаты"], symbol: "house.fill", fallback: "sparkles", color: .teal),
        Rule(terms: ["meal prep", "prepare meals", "готовить на неделю", "заготовить еду"], symbol: "frying.pan.fill", fallback: "fork.knife", color: .orange),
        Rule(terms: ["order food", "takeout", "food delivery", "заказать еду"], symbol: "takeoutbag.and.cup.and.straw.fill", fallback: "fork.knife", color: .orange),
        Rule(terms: ["grocery list", "shopping list", "список покупок"], symbol: "list.clipboard.fill", fallback: "cart.fill", color: .orange),
        Rule(terms: ["errand", "errands", "дела", "поручения"], symbol: "checklist", fallback: "list.clipboard.fill", color: .orange),
        Rule(terms: ["chores", "house chores", "домашние дела"], symbol: "checklist", fallback: "house.fill", color: .orange),
        Rule(terms: ["groceries", "grocery", "supermarket", "продукты", "супермаркет"], symbol: "cart.fill", fallback: "bag.fill", color: .orange),
        Rule(terms: ["dishes", "wash dishes", "dishwasher", "помыть посуду", "посуда"], symbol: "drop.fill", fallback: "sparkles", color: .teal),
        Rule(terms: ["vacuum", "vacuuming", "пылесос"], symbol: "sparkles", fallback: "house.fill", color: .teal),
        Rule(terms: ["bake", "baking", "печь", "выпечк"], symbol: "birthday.cake.fill", fallback: "frying.pan.fill", color: .orange),
        Rule(terms: ["restaurant", "cafe", "dining", "ресторан", "кафе"], symbol: "fork.knife", fallback: "cup.and.saucer.fill", color: .orange),
        Rule(terms: ["journal", "journaling", "diary", "дневник", "записать мысли"], symbol: "book.closed.fill", fallback: "pencil.line", color: .violet),
        Rule(terms: ["charge phone", "charge", "charging", "зарядить", "зарядка телефона"], symbol: "battery.100", fallback: "bolt.fill", color: .green),
        Rule(terms: ["sleep", "bed", "nap", "сон", "спать"], symbol: "bed.double.fill", fallback: "moon.fill", color: .indigo),
        Rule(terms: ["morning", "wake", "утро", "просну", "подъем", "подъём"], symbol: "sunrise.fill", fallback: "sun.max.fill", color: .orange),
        Rule(terms: ["breakfast", "lunch", "dinner", "food", "eat", "еда", "завтрак", "обед", "ужин"], symbol: "fork.knife", fallback: "cup.and.saucer.fill", color: .orange),
        Rule(terms: ["coffee", "tea", "кофе", "чай"], symbol: "cup.and.saucer.fill", fallback: "mug.fill", color: .orange),
        Rule(terms: ["water", "drink water", "вода", "пить воду"], symbol: "drop.fill", fallback: "water.waves", color: .teal),
        Rule(terms: ["money", "pay", "bank", "budget", "finance", "деньг", "оплат", "банк", "бюджет"], symbol: "creditcard.fill", fallback: "banknote.fill", color: .green),
        Rule(terms: ["shop", "buy", "store", "shopping", "купить", "магазин", "покуп"], symbol: "bag.fill", fallback: "cart.fill", color: .orange),
        Rule(terms: ["clean", "laundry", "tidy", "убор", "стир", "порядок"], symbol: "bubbles.and.sparkles.fill", fallback: "sparkles", color: .teal),
        Rule(terms: ["cook", "cooking", "готовить", "готовка"], symbol: "frying.pan.fill", fallback: "fork.knife", color: .orange),
        Rule(terms: ["home", "house", "дом"], symbol: "house.fill", fallback: "house", color: .orange),
        Rule(terms: ["medicine", "medication", "take medicine", "таблетк", "лекарство", "принять лекар"], symbol: "pill.fill", fallback: "cross.case.fill", color: .red),
        Rule(terms: ["therapy", "therapist", "counseling", "counselling", "терапия", "психолог"], symbol: "brain.head.profile", fallback: "bubble.left.and.bubble.right.fill", color: .teal),
        Rule(terms: ["blood test", "lab test", "анализ крови", "сдать анализы"], symbol: "drop.triangle.fill", fallback: "cross.case.fill", color: .red),
        Rule(terms: ["vaccination", "vaccine", "shot appointment", "вакцина", "прививка"], symbol: "syringe.fill", fallback: "cross.case.fill", color: .red),
        Rule(terms: ["doctor", "health", "clinic", "hospital", "врач", "здоров", "клиник", "больниц"], symbol: "cross.case.fill", fallback: "stethoscope", color: .red),
        Rule(terms: ["dentist", "зуб", "стомат"], symbol: "mouth.fill", fallback: "cross.case.fill", color: .teal),
        Rule(terms: ["vet", "veterinarian", "ветеринар", "ветклиника"], symbol: "cross.case.fill", fallback: "pawprint.fill", color: .red),
        Rule(terms: ["groom pet", "pet grooming", "груминг", "помыть собаку"], symbol: "pawprint.fill", fallback: "sparkles", color: .orange),
        Rule(terms: ["walk dog", "dog walk", "выгулять собаку", "прогулка с собакой"], symbol: "figure.walk", fallback: "pawprint.fill", color: .green),
        Rule(terms: ["feed pet", "feed dog", "feed cat", "покормить", "кормить питом"], symbol: "pawprint.fill", fallback: "fork.knife", color: .orange),
        Rule(terms: ["dog", "cat", "pet", "animal", "собак", "кошк", "питом", "живот"], symbol: "pawprint.fill", fallback: "pawprint", color: .orange),
        Rule(terms: ["appointment", "reservation", "booking", "запись", "прием", "приём"], symbol: "calendar.badge.clock", fallback: "calendar", color: .blue),
        Rule(terms: ["beach", "go to beach", "пляж"], symbol: "beach.umbrella.fill", fallback: "umbrella.fill", color: .teal),
        Rule(terms: ["camp", "camping", "кемпинг", "палатка"], symbol: "tent.fill", fallback: "tree.fill", color: .green),
        Rule(terms: ["picnic", "пикник"], symbol: "basket.fill", fallback: "leaf.fill", color: .green),
        Rule(terms: ["museum", "gallery", "музей", "галерея"], symbol: "building.columns.fill", fallback: "photo.artframe", color: .violet),
        Rule(terms: ["concert", "gig", "концерт"], symbol: "music.note", fallback: "ticket.fill", color: .violet),
        Rule(terms: ["theater", "theatre", "play show", "театр", "спектакль"], symbol: "theatermasks.fill", fallback: "ticket.fill", color: .violet),
        Rule(terms: ["cinema", "movie theater", "кинотеатр", "кино"], symbol: "film.fill", fallback: "play.rectangle.fill", color: .violet),
        Rule(terms: ["chess", "шахматы"], symbol: "checkerboard.rectangle", fallback: "gamecontroller.fill", color: .gray),
        Rule(terms: ["board game", "board games", "настольная игра", "настолки"], symbol: "dice.fill", fallback: "gamecontroller.fill", color: .orange),
        Rule(terms: ["paint", "painting", "watercolor", "рисовать красками", "живопись", "акварель"], symbol: "paintpalette.fill", fallback: "paintbrush.fill", color: .pink),
        Rule(terms: ["craft", "crafting", "handmade", "поделка", "рукоделие"], symbol: "scissors", fallback: "paintbrush.fill", color: .pink),
        Rule(terms: ["sew", "sewing", "шить", "шитье", "шитьё"], symbol: "scissors", fallback: "tshirt.fill", color: .violet),
        Rule(terms: ["knit", "knitting", "crochet", "вязать", "вязание"], symbol: "circle.hexagongrid.fill", fallback: "tshirt.fill", color: .violet),
        Rule(terms: ["water plants", "watering plants", "полить цветы", "полить растения"], symbol: "drop.fill", fallback: "leaf.fill", color: .green),
        Rule(terms: ["practice piano", "piano practice", "practice guitar", "guitar practice", "instrument practice", "играть на пианино", "играть на гитаре", "занятие музыкой"], symbol: "music.note", fallback: "headphones", color: .violet),
        Rule(terms: ["photo", "camera", "фото", "камер"], symbol: "camera.fill", fallback: "photo.fill", color: .pink),
        Rule(terms: ["video", "movie", "film", "видео", "фильм"], symbol: "play.rectangle.fill", fallback: "film.fill", color: .violet),
        Rule(terms: ["music", "piano", "guitar", "song", "музык", "пианино", "гитар"], symbol: "music.note", fallback: "headphones", color: .violet),
        Rule(terms: ["social media", "instagram", "tiktok", "threads", "соцсети", "инстаграм", "тикток"], symbol: "bubble.left.and.bubble.right.fill", fallback: "person.2.fill", color: .pink),
        Rule(terms: ["browse web", "web research", "internet", "google search", "поиск в интернете", "интернет"], symbol: "safari.fill", fallback: "globe", color: .blue),
        Rule(terms: ["password", "change password", "пароль", "сменить пароль"], symbol: "key.fill", fallback: "lock.fill", color: .gray),
        Rule(terms: ["wifi", "wi fi", "internet setup", "вайфай", "wi-fi"], symbol: "wifi", fallback: "network", color: .blue),
        Rule(terms: ["software update", "update app", "update phone", "обновить приложение", "обновление"], symbol: "arrow.triangle.2.circlepath", fallback: "gearshape.fill", color: .blue),
        Rule(terms: ["plan", "calendar", "schedule", "план", "календар", "распис"], symbol: "calendar", fallback: "calendar.badge.clock", color: .blue),
        Rule(terms: ["focus", "deep work", "фокус", "концентр"], symbol: "scope", fallback: "target", color: .indigo),
        Rule(terms: ["idea", "think", "brainstorm", "иде", "думать"], symbol: "lightbulb.fill", fallback: "brain", color: .yellow),
        Rule(terms: ["goal", "target", "цель"], symbol: "target", fallback: "flag.fill", color: .red),
        Rule(terms: ["habit", "routine", "привыч", "рутин"], symbol: "repeat.circle.fill", fallback: "repeat", color: .green),
        Rule(terms: ["birthday", "party", "день рождения", "праздник"], symbol: "birthday.cake.fill", fallback: "gift.fill", color: .pink),
        Rule(terms: ["gift", "present", "подар"], symbol: "gift.fill", fallback: "gift", color: .pink),
        Rule(terms: ["game", "gaming", "игр"], symbol: "gamecontroller.fill", fallback: "gamecontroller", color: .violet),
        Rule(terms: ["tv", "show", "series", "сериал"], symbol: "tv.fill", fallback: "play.rectangle.fill", color: .violet),
        Rule(terms: ["garden", "plant", "flower", "сад", "растен", "цвет"], symbol: "leaf.fill", fallback: "tree.fill", color: .green),
        Rule(terms: ["document", "file", "report", "документ", "отчет", "отчёт"], symbol: "doc.text.fill", fallback: "doc.fill", color: .blue),
        Rule(terms: ["repair", "fix", "tool", "почин", "ремонт"], symbol: "wrench.and.screwdriver.fill", fallback: "hammer.fill", color: .orange),
        Rule(terms: ["pack", "backpack", "собрать рюкзак", "рюкзак"], symbol: "backpack.fill", fallback: "bag.fill", color: .orange),
        Rule(terms: ["meditate", "mindfulness", "breath", "медитац", "дых"], symbol: "figure.mind.and.body", fallback: "leaf.fill", color: .teal),
        Rule(terms: ["rest", "break", "relax", "отдых", "перерыв"], symbol: "leaf.fill", fallback: "cup.and.saucer.fill", color: .green)
    ]

    static func symbol(for title: String, category: TaskCategory? = nil) -> String {
        if let rule = matchingRule(for: title) { return safeSymbol(rule.symbol, fallback: rule.fallback) }
        switch category {
        case .focus: return safeSymbol("scope", fallback: "target")
        case .work: return safeSymbol("briefcase.fill", fallback: "briefcase")
        case .study: return safeSymbol("graduationcap.fill", fallback: "book.fill")
        case .fitness: return safeSymbol("figure.run", fallback: "dumbbell.fill")
        case .rest: return safeSymbol("leaf.fill", fallback: "moon.fill")
        default: return safeSymbol("circle.grid.2x2.fill", fallback: "circle.fill")
        }
    }

    static func symbol(for task: PlannerTask) -> String {
        let semantic = symbol(for: task.title, category: task.category)

        // Explicit automatic mode always follows the current title/category.
        if task.iconIsAutomatic == true { return semantic }

        // Explicit custom mode must never be "repaired" back to a semantic icon. This
        // is what makes the icon picker authoritative after the user chooses a symbol.
        if task.iconIsAutomatic == false, let existing = task.icon, !existing.isEmpty {
            return safeSymbol(existing, fallback: semantic)
        }

        // Legacy snapshots did not store iconIsAutomatic. Repair only those ambiguous
        // old values, while all new custom choices stay untouched.
        guard let existing = task.icon, !existing.isEmpty else { return semantic }
        if shouldRepair(existing: existing, title: task.title, category: task.category) { return semantic }
        return safeSymbol(existing, fallback: semantic)
    }

    static func suggestedColor(for title: String, category: TaskCategory? = nil) -> TaskColor {
        if let rule = matchingRule(for: title) { return rule.color }
        switch category {
        case .focus: return .indigo
        case .work: return .blue
        case .study: return .violet
        case .fitness: return .green
        case .rest: return .teal
        default: return .gray
        }
    }

    /// Repairs icons produced by older automatic matching without overwriting deliberate custom choices.
    static func shouldRepair(existing: String?, title: String, category: TaskCategory?) -> Bool {
        guard let existing, !existing.isEmpty else { return true }
        let desired = symbol(for: title, category: category)
        guard existing != desired else { return false }

        let generic = Set(["circle.grid.2x2.fill", "circle.fill"])
        if generic.contains(existing) { return true }

        // Older builds persisted automatically selected symbols as if they were custom.
        // If the title now strongly matches another semantic rule and the existing value
        // is one of our own rule-generated symbols/fallbacks, safely refresh it.
        if matchingRule(for: title) != nil {
            let automaticSymbols = Set(rules.flatMap { [$0.symbol, $0.fallback] })
            if automaticSymbols.contains(existing) { return true }
        }

        let normalized = normalize(title)
        let fitnessWords = ["training", "workout", "трениров", "fitness", "gym"]
        if existing == "tram.fill" && fitnessWords.contains(where: normalized.contains) { return true }
        if ["shower", "душ", "помыться", "мыться"].contains(where: normalized.contains) { return true }
        return false
    }

    private static func matchingRule(for title: String) -> Rule? {
        let normalized = normalize(title)
        let tokens = Set(normalized.split(separator: " ").map(String.init))
        return rules.first { rule in
            rule.terms.contains { term in
                let normalizedTerm = normalize(term)
                if normalizedTerm.contains(" ") {
                    return normalized.contains(normalizedTerm)
                }
                if normalizedTerm.count <= 3 {
                    return tokens.contains(normalizedTerm)
                }
                return tokens.contains(where: { $0 == normalizedTerm || $0.hasPrefix(normalizedTerm) })
            }
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "а-яА-Я")).inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func safeSymbol(_ preferred: String, fallback: String) -> String {
        #if canImport(UIKit)
        if UIImage(systemName: preferred) != nil { return preferred }
        if UIImage(systemName: fallback) != nil { return fallback }
        return "circle.grid.2x2.fill"
        #else
        // Core regression tests run on non-Apple CI where SF Symbols/UIKit are unavailable.
        // On iOS the branch above validates the actual system symbol before using it.
        return preferred.isEmpty ? fallback : preferred
        #endif
    }
}
