//
//  AddTransactionView.swift
//  FinanceFlow
//
//  Formulario para agregar transacciones manualmente.
//  Punto de integración: LLM para categorización automática, SMS para importar.
//

import SwiftUI
import UIKit

struct AddTransactionView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var selectedCategory: Category?
    @State private var selectedType: TransactionType = .expense
    @State private var selectedFixedVariable: TransactionFixedVariable = .variable
    @State private var date = Date()
    @State private var note = ""
    @State private var showingError = false
    @State private var showingConnectionResult = false
    @State private var connectionResultMessage = ""
    @State private var showingClipboardError = false
    @State private var selectedCard: Card?

    private var filteredCategories: [Category] {
        viewModel.categories.filter { $0.transactionType == selectedType }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Pegar desde mensaje (SMS/banco)", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Importar")
                } footer: {
                    Text("Copia un mensaje de tu banco (ej. DAVIbank) y pégalo aquí para completar monto, descripción y fecha.")
                }

                Section("Tipo") {
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedType) { _, _ in
                        selectedCategory = nil
                    }
                }

                Section {
                    Picker("Fijo o variable", selection: $selectedFixedVariable) {
                        ForEach(TransactionFixedVariable.allCases) { fv in
                            Text(fv.displayName).tag(fv)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Naturaleza")
                } footer: {
                    Text("Fijo: gastos/ingresos recurrentes (renta, salario). Variable: ocasionales (compras, salidas).")
                }

                Section("Monto") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }

                Section("Tarjeta (opcional)") {
                    if viewModel.cards.isEmpty {
                        Text("No hay tarjetas. Agrega una desde el Dashboard.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Tarjeta", selection: $selectedCard) {
                            Text("Ninguna").tag(nil as Card?)
                            ForEach(viewModel.cards) { card in
                                Label(card.name, systemImage: card.type.iconName)
                                    .tag(card as Card?)
                            }
                        }
                    }
                }

                Section("Categoría") {
                    if filteredCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if let error = viewModel.errorMessage {
                                Text("Error de conexión: \(error)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("No hay categorías. Comprueba la conexión y que hayas ejecutado las migraciones en Supabase.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 12) {
                                Button("Reintentar") {
                                    Task { await viewModel.loadData() }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Categoría", selection: $selectedCategory) {
                            Text("Seleccionar").tag(nil as Category?)
                            ForEach(filteredCategories) { category in
                                Label(category.name, systemImage: category.iconName)
                                    .tag(category as Category?)
                            }
                        }
                    }
                }

                Section("Fecha") {
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                Section("Nota (opcional)") {
                    TextField("Descripción o nota", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Nueva Transacción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveTransaction()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "No se pudo guardar la transacción.")
            }
            .alert("Portapapeles", isPresented: $showingClipboardError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No se encontró un mensaje de transacción válido en el portapapeles. Copia un SMS o notificación de tu banco (ej. \"Realizaste transacción en X por 49,600...\").")
            }
        }
    }

    /// Lee el portapapeles, parsea un mensaje tipo banco/SMS y rellena el formulario.
    private func pasteFromClipboard() {
        let pasteboard = UIPasteboard.general
        guard let text = pasteboard.string else {
            showingClipboardError = true
            return
        }
        guard let parsed = ClipboardTransactionParser.parse(text) else {
            showingClipboardError = true
            return
        }
        amountText = NSDecimalNumber(decimal: parsed.amount).stringValue
        note = parsed.note
        date = parsed.date
        selectedType = parsed.type
        selectedCategory = nil
    }

    private var isFormValid: Bool {
        guard let amount = CurrencyFormatter.shared.parse(amountText, currency: viewModel.selectedCurrency),
              amount > 0 else { return false }
        return selectedCategory != nil
    }

    private func saveTransaction() {
        guard let amount = CurrencyFormatter.shared.parse(amountText, currency: viewModel.selectedCurrency),
              amount > 0,
              let category = selectedCategory else { return }

        let transaction = Transaction(
            amount: amount,
            categoryId: category.id,
            cardId: selectedCard?.id,
            date: date,
            note: note.isEmpty ? nil : note,
            type: selectedType,
            fixedVariable: selectedFixedVariable
        )

        Task {
            await viewModel.addTransaction(transaction)
            if viewModel.errorMessage == nil {
                dismiss()
            } else {
                print("[AddTransactionView] Error guardando: \(viewModel.errorMessage ?? "desconocido")")
                showingError = true
            }
        }
    }
}

#Preview {
    AddTransactionView()
        .environment(TransactionViewModel())
}
