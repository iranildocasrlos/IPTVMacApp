// ContentView.swift atualizado

import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct Canal: Identifiable, Codable, Equatable {
    let id = UUID()
    let nome: String
    let url: String
    let logo: String?
    let qualidade: String?
    let tvgID: String?
}

struct ProgramaEPG: Identifiable {
    let id = UUID()
    let canalID: String
    let titulo: String
    let inicio: Date
    let fim: Date
}



struct ListaIPTV: Identifiable, Codable {
    let id = UUID()
    var nome: String
    var url: String
}

class AppState: ObservableObject {
    @Published var canais: [Canal] = []
    @Published var favoritos: Set<String> = []
    @Published var historico: [Canal] = []
    @Published var listasSalvas: [ListaIPTV] = []
    

    init() {
        if let data = UserDefaults.standard.data(forKey: "favoritos"),
           let favs = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoritos = favs
        }
        if let data = UserDefaults.standard.data(forKey: "historico"),
           let hist = try? JSONDecoder().decode([Canal].self, from: data) {
            historico = hist
        }
        if let data = UserDefaults.standard.data(forKey: "listasSalvas"),
           let listas = try? JSONDecoder().decode([ListaIPTV].self, from: data) {
            listasSalvas = listas
        }
    }
    
    
    
    func salvarEstado() {
        if let data = try? JSONEncoder().encode(favoritos) {
            UserDefaults.standard.set(data, forKey: "favoritos")
        }
        if let data = try? JSONEncoder().encode(historico) {
            UserDefaults.standard.set(data, forKey: "historico")
        }
        if let data = try? JSONEncoder().encode(listasSalvas) {
            UserDefaults.standard.set(data, forKey: "listasSalvas")
        }
    }

    func removerLista(_ lista: ListaIPTV) {
        listasSalvas.removeAll { $0.id == lista.id }
        salvarEstado()
    }
}


func carregarEPG(from url: URL, completion: @escaping ([ProgramaEPG]) -> Void) {
    DispatchQueue.global().async {
        var programas: [ProgramaEPG] = []

        guard let parser = XMLParser(contentsOf: url) else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        class ParserDelegate: NSObject, XMLParserDelegate {
            var programas: [ProgramaEPG] = []
            var currentElement = ""
            var canalID = ""
            var titulo = ""
            var inicio = ""
            var fim = ""

            let formatter: DateFormatter = {
                let df = DateFormatter()
                df.dateFormat = "yyyyMMddHHmmss Z"
                return df
            }()

            func parser(_ parser: XMLParser, didStartElement elementName: String,
                        namespaceURI: String?, qualifiedName qName: String?,
                        attributes attributeDict: [String : String] = [:]) {
                currentElement = elementName

                if elementName == "programme" {
                    canalID = attributeDict["channel"] ?? ""
                    inicio = attributeDict["start"] ?? ""
                    fim = attributeDict["stop"] ?? ""
                    titulo = ""
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                if currentElement == "title" {
                    titulo += string
                }
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String,
                        namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "programme" {
                    if let inicioDate = formatter.date(from: inicio),
                       let fimDate = formatter.date(from: fim) {
                        let programa = ProgramaEPG(canalID: canalID, titulo: titulo, inicio: inicioDate, fim: fimDate)
                        programas.append(programa)
                    }
                }
            }
        }

        let delegate = ParserDelegate()
        parser.delegate = delegate
        parser.parse()

        DispatchQueue.main.async {
            completion(delegate.programas)
        }
    }
}





var fullscreenWindow: NSWindow?

func abrirTelaCheiaCom(url: String) {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 800, 600),
        styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    let controller = PlayerController()
    controller.play(url: url)

    let view = NSHostingView(rootView:
        FullscreenPlayerView(controller: controller) {
            controller.stop()
            window.close()
        }
    )

    window.contentView = view
    window.makeKeyAndOrderFront(nil)
}




struct ContentView: View {
    @StateObject private var estado = AppState()
    @State private var buscaTexto = ""
    @State private var qualidadeFiltro = "Todos"
    @State private var urlAtual = ""
    @State private var canalSelecionado: Canal?
    @State private var modoPlayer = "embutido"
    @State private var novaListaURL = ""
    @State private var novaListaNome = ""
    @State private var carregando = false
    @State private var progresso: Double = 0.0
    @State private var fullscreenPlayer: Canal?
    @State private var destacarPlayer: Canal?
    @State private var mostrandoFavoritos = false
    @State private var mostrandoImportador = false
    @State private var mostrandoImportadorEPG = false
    @State private var epg: [ProgramaEPG] = []
    @State private var epgURL = "https://iptv-org.github.io/epg/guides/br.xml"

    func epgParaCanal(_ canal: Canal) -> (String?, String?) {
        guard let id = canal.tvgID else { return (nil, nil) }
        let agora = Date()
        let programasDoCanal = epg
            .filter { $0.canalID == id }
            .sorted { $0.inicio < $1.inicio }

        let atual = programasDoCanal.first { $0.inicio <= agora && agora <= $0.fim }
        let proximo = programasDoCanal.first { $0.inicio > agora }

        return (atual?.titulo, proximo?.titulo)
    }

    var body: some View {
        HStack {
            VStack {
                Picker("Qualidade", selection: $qualidadeFiltro) {
                    Text("Todos").tag("Todos")
                    Text("HD").tag("HD")
                    Text("SD").tag("SD")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                HStack {
                    TextField("Buscar canal...", text: $buscaTexto)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(mostrandoFavoritos ? "← Voltar" : "⭐ Favoritos") {
                        if mostrandoFavoritos {
                            mostrandoFavoritos = false
                            carregarListaM3U(from: urlAtual)
                        } else {
                            estado.canais = estado.canais.filter { estado.favoritos.contains($0.nome) }
                            mostrandoFavoritos = true
                        }
                    }
                }
                .padding()

                if carregando {
                    ProgressView(value: progresso)
                        .padding()
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))]) {
                        ForEach(filtrarCanais()) { canal in
                            VStack {
                                if let logo = canal.logo, let logoURL = URL(string: logo) {
                                    AsyncImage(url: logoURL) { img in
                                        img.resizable()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 100, height: 100)
                                }
                                Text(canal.nome).font(.caption).multilineTextAlignment(.center)
                                let (atual, proximo) = epgParaCanal(canal)

                                if atual != nil || proximo != nil {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let atual = atual {
                                            Text("📺 Agora: \(atual)")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                                .lineLimit(1)
                                        }
                                        if let proximo = proximo {
                                            Text("⏭ Próximo: \(proximo)")
                                                .font(.caption2)
                                                .foregroundColor(.yellow)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                                }


                                HStack {
                                    Button("▶️ Assistir") {
                                        canalSelecionado = canal
                                        estado.historico.insert(canal, at: 0)
                                        estado.salvarEstado()
                                    }
                                    Button(estado.favoritos.contains(canal.nome) ? "⭐" : "☆") {
                                        if estado.favoritos.contains(canal.nome) {
                                            estado.favoritos.remove(canal.nome)
                                        } else {
                                            estado.favoritos.insert(canal.nome)
                                        }
                                        estado.salvarEstado()
                                    }
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
                        }
                    }
                    .padding()
                }

                Divider()

                VStack {
                    
                    Text("URL atual:").font(.caption)
                    
                    HStack{
                        TextField("Insira URL da lista M3U", text: $urlAtual)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        Button("Carregar Lista IPTV") {
                            carregarListaM3U(from: urlAtual)
                        }
                    }
                   
                    
                    HStack{
                       

                        Button("📂 Importar .m3u") {
                            mostrandoImportador = true
                        }
                        .fileImporter(isPresented: $mostrandoImportador, allowedContentTypes: [UTType(filenameExtension: "m3u") ?? .plainText]) { result in

                            do {
                                let fileURL = try result.get()
                                let content = try String(contentsOf: fileURL, encoding: .utf8)
                                let canais = parseM3UContent(content)
                                estado.canais = canais
                            } catch {
                                print("Erro ao importar lista: \(error)")
                            }
                        }
                        
                        Button("📄 Importar EPG (.xml)") {
                            mostrandoImportadorEPG = true
                        }
                        .fileImporter(isPresented: $mostrandoImportadorEPG, allowedContentTypes: [.xml]) { result in
                            do {
                                let fileURL = try result.get()
                                    carregarEPG(from: fileURL) { programas in
                                    epg = programas
                                }
                            } catch {
                                print("Erro ao importar EPG: \(error)")
                            }
                        }
                    }
                    
                    

                    HStack {
                        TextField("Nome da lista", text: $novaListaNome)
                        TextField("URL", text: $novaListaURL)
                        Button("Salvar Lista") {
                            guard !novaListaNome.isEmpty, !novaListaURL.isEmpty else { return }
                            estado.listasSalvas.append(ListaIPTV(nome: novaListaNome, url: novaListaURL))
                            estado.salvarEstado()
                            novaListaNome = ""
                            novaListaURL = ""
                        }
                    }
                    .padding()

                    
                    Text("LISTAS SALVAS").font(.caption)
                    ScrollView(.horizontal) {
                        HStack {
                           
                            
                            ForEach(estado.listasSalvas) { lista in
                                HStack {
                                    Button(lista.nome) {
                                        urlAtual = lista.url
                                        carregarListaM3U(from: lista.url)
                                    }
                                    Button("🗑️") {
                                        estado.removerLista(lista)
                                    }
                                    .foregroundColor(.red)
                                }
                                .padding(6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .frame(minWidth: 420)

            if let canal = canalSelecionado {
                @StateObject var playerController = PlayerController()
                
                VStack {
                    Text("Reproduzindo: \(canal.nome)")
                        .font(.headline)
                        .foregroundColor(.white)
                    VideoPlayer(player: AVPlayer(url: URL(string: canal.url)!))
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .cornerRadius(12)
                        .padding(.bottom)
                    HStack {
                        Button("🔳 Tela Cheia") {
                            playerController.stop()
                            abrirTelaCheiaCom(url: canal.url)
                        }
                        Button("📤 Destacar") {
                            destacarPlayer = canal
                        }
                        Button("✖️ Fechar") {
                            canalSelecionado = nil
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.9))
            } else {
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
     
    }

    func filtrarCanais() -> [Canal] {
        return estado.canais.filter {
            (buscaTexto.isEmpty || $0.nome.localizedCaseInsensitiveContains(buscaTexto)) &&
            (qualidadeFiltro == "Todos" || $0.qualidade?.contains(qualidadeFiltro) == true)
        }
    }

    func carregarListaM3U(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        carregando = true
        progresso = 0.0

        URLSession.shared.dataTask(with: url) { data, _, error in
            defer { DispatchQueue.main.async { carregando = false } }

            guard let data = data,
                  let conteudo = String(data: data, encoding: .utf8),
                  error == nil else {
                return
            }

            let canais = parseM3UContent(conteudo)

            DispatchQueue.main.async {
                estado.canais = canais
                progresso = 1.0
            }

        }.resume()
    }

    func parseM3UContent(_ content: String) -> [Canal] {
        var canais: [Canal] = []
        let linhas = content.components(separatedBy: .newlines)
        var nome = ""
        var logo: String?
        var qualidade: String?
        var tvgID: String?

        for i in 0..<linhas.count {
            let linha = linhas[i]
            if linha.starts(with: "#EXTINF") {
                nome = ""
                logo = nil
                qualidade = "Outros"
                tvgID = nil

                if let range = linha.range(of: ",") {
                    nome = String(linha[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                }

                if let logoRange = linha.range(of: "tvg-logo=\"") {
                    let start = linha[logoRange.upperBound...]
                    if let end = start.range(of: "\"") {
                        logo = String(start[..<end.lowerBound])
                    }
                }

                if let idRange = linha.range(of: "tvg-id=\"") {
                    let start = linha[idRange.upperBound...]
                    if let end = start.range(of: "\"") {
                        tvgID = String(start[..<end.lowerBound])
                    }
                }

                if linha.contains("HD") || linha.contains("720") || linha.contains("1080") {
                    qualidade = "HD"
                } else if linha.contains("SD") || linha.contains("480") {
                    qualidade = "SD"
                }
            } else if linha.starts(with: "http") || linha.starts(with: "rtmp") {
                canais.append(Canal(nome: nome, url: linha, logo: logo, qualidade: qualidade, tvgID: tvgID))
            }

            DispatchQueue.main.async {
                progresso = Double(i) / Double(linhas.count)
            }
        }

        return canais
    }

}
