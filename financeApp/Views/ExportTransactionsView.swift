//
//  ExportTransactionsView.swift
//  FinanceFlow
//
//  Vista para exportar transacciones a CSV con selector de rango de fechas.
//  Mínimo: 1 semana. Máximo: 2 meses.
//

import SwiftUI

struct ExportTransactionsView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    }()
    @State private var endDate: Date = Date()
    @State private var validationError: String?
    @State private var showingShareSheet = false
    @State private var csvURL: URL?

    private let calendar = Calendar.current

    private var filteredTransactions: [Transaction] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        return viewModel.transactions.filter { tx in
            tx.date >= start && tx.date < end
        }
    }

    private var dateRangeValidation: (isValid: Bool, message: String?) {
        switch TransactionExportService.validateDateRange(from: startDate, to: endDate) {
        case .success:
            return (true, nil)
        case .failure(.dateRangeTooShort):
            return (false, "El rango debe ser de al menos 1 semana (7 días)")
        case .failure(.dateRangeTooLong):
            return (false, "El rango no puede superar 2 meses (60 días)")
        case .failure(.noTransactions):
            return (false, nil) // No aplica en validación de rango
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha inicio", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, _ in validationError = nil }
                    DatePicker("Fecha fin", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .onChange(of: endDate) { _, _ in validationError = nil }
                } header: {
                    Text("Rango de fechas")
                } footer: {
                    Text("Mínimo: 1 semana. Máximo: 2 meses.")
                }

                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    HStack {
                        Text("Transacciones en el rango")
                        Spacer()
                        Text("\(filteredTransactions.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        exportAndShare()
                    } label: {
                        Label("Exportar a CSV", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!dateRangeValidation.isValid || filteredTransactions.isEmpty)
                }
            }
            .navigationTitle("Exportar transacciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportAndShare() {
        let (isValid, message) = dateRangeValidation
        guard isValid else {
            validationError = message
            return
        }

        guard !filteredTransactions.isEmpty else {
            validationError = "No hay transacciones en el rango seleccionado"
            return
        }

        let csv = TransactionExportService.generateCSV(
            transactions: filteredTransactions,
            categories: viewModel.categories,
            cards: viewModel.cards,
            currency: viewModel.selectedCurrency
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "transacciones_\(dateFormatter.string(from: startDate))_\(dateFormatter.string(from: endDate)).csv"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            showingShareSheet = true
        } catch {
            validationError = "Error al crear el archivo: \(error.localizedDescription)"
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportTransactionsView()
        .environment(TransactionViewModel())
}
