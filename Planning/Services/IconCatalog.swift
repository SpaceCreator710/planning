import SwiftUI
import UIKit

enum IconCatalog {
    private static let bases = [
        "airplane","alarm","archivebox","arrow.clockwise","backpack","bag","bandage","banknote","basketball","battery.100","bed.double","bell","bicycle","binoculars","birthday.cake","bolt","book","book.closed","bookmark","brain","briefcase","building.2","bus","calendar","camera","camera.macro","car","cart","chart.bar","chart.line.uptrend.xyaxis","checkmark.seal","checklist","circle.grid.2x2","clock","cloud","cup.and.saucer","desktopcomputer","display","doc","doc.text","door.left.hand.open","drop","dumbbell","envelope","eraser","eye","face.smiling","film","flag","flame","folder","fork.knife","gamecontroller","gift","globe","graduationcap","hammer","headphones","heart","house","key","keyboard","laptopcomputer","leaf","lightbulb","link","location","lock","magnifyingglass","map","medal","medical.thermometer","message","mic","moon","music.note","newspaper","paintbrush","paperclip","pawprint","pencil","person","person.2","phone","photo","pill","pin","play.rectangle","printer","puzzlepiece","questionmark","rectangle.3.group","repeat","scissors","scope","shippingbox","shoe","soccerball","sparkles","star","stethoscope","stopwatch","sun.max","tag","target","tennis.racket","text.book.closed","timer","tram","tree","trophy","truck.box","umbrella","video","wallet.pass","wand.and.stars","waveform","wifi","wrench.and.screwdriver",
        "figure.archery","figure.badminton","figure.barre","figure.basketball","figure.boxing","figure.climbing","figure.cooldown","figure.core.training","figure.cricket","figure.cross.training","figure.curling","figure.dance","figure.disc.sports","figure.elliptical","figure.equestrian.sports","figure.fencing","figure.fishing","figure.flexibility","figure.golf","figure.gymnastics","figure.hand.cycling","figure.hiking","figure.hockey","figure.hunting","figure.indoor.cycle","figure.jumprope","figure.kickboxing","figure.lacrosse","figure.mind.and.body","figure.open.water.swim","figure.outdoor.cycle","figure.pickleball","figure.pilates","figure.play","figure.pool.swim","figure.racquetball","figure.roll","figure.rower","figure.rugby","figure.run","figure.sailing","figure.skating","figure.skiing.crosscountry","figure.skiing.downhill","figure.snowboarding","figure.soccer","figure.socialdance","figure.softball","figure.squash","figure.stair.stepper","figure.stairs","figure.step.training","figure.strengthtraining.functional","figure.strengthtraining.traditional","figure.surfing","figure.table.tennis","figure.taichi","figure.tennis","figure.track.and.field","figure.volleyball","figure.walk","figure.water.fitness","figure.waterpolo","figure.wrestling","figure.yoga",
        "atom","function","plus.forwardslash.minus","triangle","flask","microbe","building.columns","character.book.closed","paintpalette","mouth","shower","frying.pan","scalemass","cpu","gearshape.2","leaf.circle","mountain.2","snowflake","sportscourt","baseball","brain.head.profile",
        "apple.logo","applescript","apps.iphone","at","barcode","books.vertical","bubble.left","bubble.left.and.bubble.right","calendar.badge.clock","calendar.badge.plus","chart.pie","clock.badge","command","creditcard","crown","cube","diamond","dice","ear","ellipsis","exclamationmark.triangle","externaldrive","eyeglasses","facemask","faxmachine","ferry","fuelpump","gearshape","globe.americas","hand.raised","hare","headphones.circle","heart.text.square","homepod","hourglass","icloud","iphone","ipad","keyboard.badge.ellipsis","lanyardcard","list.bullet","list.clipboard","macbook","mail","megaphone","memorychip","network","paperplane","party.popper","person.crop.circle","person.crop.square","person.wave.2","phone.arrow.up.right","pin.circle","powerplug","radio","rectangle.and.pencil.and.ellipsis","rectangle.stack","rocket","ruler","safari","server.rack","shield","shippingbox.and.arrow.backward","signpost.right","simcard","speaker.wave.2","square.and.arrow.up","square.and.pencil","square.grid.2x2","staroflife","studentdesk","suitcase","table.furniture","textformat","ticket","toilet","touchid","tv","visionpro","watch.analog","water.waves","waveform.path.ecg","web.camera","wineglass",
        "airpods","airpodspro","antenna.radiowaves.left.and.right","app.badge","arrow.3.trianglepath","arrow.down.circle","arrow.down.doc","arrow.up.circle","arrow.up.doc","arrow.triangle.2.circlepath","archivebox.circle","basket","bathtub","beach.umbrella","bell.badge","bolt.car","bolt.heart","brain.filled.head.profile","briefcase.circle","building.2.crop.circle","calendar.badge.exclamationmark","calendar.day.timeline.left","calendar.day.timeline.right","car.side","cart.badge.plus","chart.bar.xaxis","chart.line.downtrend.xyaxis","checkmark.seal","checkerboard.rectangle","circle.hexagongrid","clipboard","clock.arrow.circlepath","cloud.sun","cross.case","delete.left","doc.badge.arrow.up","doc.badge.clock","doc.richtext","doc.text.magnifyingglass","doc.viewfinder","dollarsign.circle","door.garage.closed","drop.triangle","externaldrive.badge.timemachine","figure.american.football","figure.baseball","figure.handball","figure.martial.arts","figure.skateboarding","film.stack","folder.badge.plus","folder.circle","fuelpump.circle","gauge.with.dots.needle.33percent","guitars","hand.thumbsup","hand.wave","handbag","heart.circle","house.and.flag","icloud.and.arrow.down","icloud.and.arrow.up","key.horizontal","ladybug","lightbulb.max","list.bullet.clipboard","list.bullet.rectangle.portrait","location.circle","lock.shield","mail.stack","map.circle","megaphone","message.badge","mic.badge.plus","moon.stars","mug","note","note.text","paperplane.circle","parkingsign.circle","person.2.badge.gearshape","person.2.wave.2","person.crop.rectangle","person.crop.rectangle.badge.plus","person.text.rectangle","photo.artframe","photo.on.rectangle.angled","pills","power.circle","printer.dotmatrix","rectangle.stack.badge.plus","repeat.circle","shippingbox.circle","signature","sink","spraybottle","suitcase.rolling","syringe","tablecells","takeoutbag.and.cup.and.straw","tent","theatermasks","thermometer.medium","ticket","trash.circle","tray.and.arrow.down","tray.and.arrow.up","tshirt","washer","waveform.badge.mic","wrench.adjustable","xmark.seal",
    ]

    private static let suffixes = ["", ".fill", ".circle", ".circle.fill", ".square", ".square.fill"]

    static let available: [String] = {
        var seen = Set<String>()
        var result: [String] = []
        for base in bases {
            for suffix in suffixes {
                let name = base + suffix
                guard seen.insert(name).inserted, UIImage(systemName: name) != nil else { continue }
                result.append(name)
            }
        }
        return result
    }()
}

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    @State private var search = ""

    private var icons: [String] {
        guard !search.isEmpty else { return IconCatalog.available }
        return IconCatalog.available.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 10)], spacing: 10) {
                    ForEach(icons, id: \.self) { symbol in
                        Button {
                            selection = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .font(.title3)
                                .frame(width: 52, height: 52)
                                .glassEffect(
                                    .regular
                                        .tint(selection == symbol ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.045))
                                        .interactive(),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Icons")
            .searchable(text: $search, prompt: "Search symbol name")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
