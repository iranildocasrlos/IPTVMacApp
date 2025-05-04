
// ContentView.swift atualizado com remoção de playlists e retorno de favoritos

import SwiftUI
import AVKit

struct Canal: Identifiable, Codable, Equatable {
    let id = UUID()
    let nome: String
    let url: String
    let logo: String?
    let qualidade: String?
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
                    TextField("Insira URL da lista M3U", text: $urlAtual)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button("Carregar Lista IPTV") {
                        carregarListaM3U(from: urlAtual)
                    }

                    HStack {
                        TextField("Nome da lista", text: $novaListaNome)
                        TextField("URL", text: $novaListaURL)
                        Button("Salvar Lista") {
                            estado.listasSalvas.append(ListaIPTV(nome: novaListaNome, url: novaListaURL))
                            estado.salvarEstado()
                        }
                    }
                    .padding()

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
                            fullscreenPlayer = canal
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
        .sheet(item: $fullscreenPlayer) { canal in
            VStack {
                VideoPlayer(player: AVPlayer(url: URL(string: canal.url)!))
                    .edgesIgnoringSafeArea(.all)
                Button("✖️ Fechar") {
                    fullscreenPlayer = nil
                }
            }
        }
        .sheet(item: $destacarPlayer) { canal in
            VStack {
                VideoPlayer(player: AVPlayer(url: URL(string: canal.url)!))
                    .frame(minWidth: 600, minHeight: 400)
                HStack {
                    Button("📥 Reincorporar") {
                        destacarPlayer = nil
                    }
                    Button("✖️ Fechar") {
                        destacarPlayer = nil
                        canalSelecionado = nil
                    }
                }
                .padding()
            }
        }
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

            guard let data = data, error == nil,
                  let conteudo = String(data: data, encoding: .utf8) else { return }

            let linhas = conteudo.components(separatedBy: .newlines)
            var nome = ""
            var logo: String?
            var qualidade: String?
            var canais: [Canal] = []

            for i in 0..<linhas.count {
                let linha = linhas[i]
                if linha.hasPrefix("#EXTINF") {
                    if let range = linha.range(of: ",") {
                        nome = String(linha[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                    if let logoRange = linha.range(of: "tvg-logo=\"") {
                        let start = linha[logoRange.upperBound...]
                        if let end = start.range(of: "\"") {
                            logo = String(start[..<end.lowerBound])
                        }
                    }
                    if linha.contains("HD") || linha.contains("720") {
                        qualidade = "HD"
                    } else if linha.contains("SD") || linha.contains("480") {
                        qualidade = "SD"
                    } else {
                        qualidade = "Outros"
                    }
                } else if linha.hasPrefix("http") {
                    canais.append(Canal(nome: nome, url: linha, logo: logo, qualidade: qualidade))
                }
                DispatchQueue.main.async {
                    progresso = Double(i) / Double(linhas.count)
                }
            }
            DispatchQueue.main.async {
                estado.canais = canais
            }
        }.resume()
    }
}
