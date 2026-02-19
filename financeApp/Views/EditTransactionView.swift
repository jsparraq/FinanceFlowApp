//
//  EditTransactionView.swift
//  FinanceFlow
//
//  Formulario para editar transacciones existentes.
//  Permite cambiar categoría y monto. El tipo (ingreso/gasto) no se puede modificar.
//

import SwiftUI

struct EditTransactionView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction

    @State private var amountText: String
    @State private var selectedCategory: Category?
    @State private var selectedCard: Card?
    @State private var date: Date
    @State private var note: String
    @State private var showingError = false

    init(transaction: Transaction) {
        self.transaction = transaction
        _amountText = State(initialValue: NSDecimalNumber(decimal: transaction.amount).stringValue)
        _date = State(initialValue: transaction.date)
        _note = State(initialValue: transaction.note ?? "")
    }

    /// Categorías filtradas por el tipo de la transacción (ingreso o gasto).
    /// El tipo no se puede cambiar.
    private var filteredCategories: [Category] {
        viewModel.categories.filter { $0.transactionType == transaction.type }
    }

    var body: some View {
        Form {
                Section {
                    Text(transaction.type.displayName)
                        .font(.headline)
                        .foregroundStyle(transaction.type == .income ? .green : .red)
                } header: {
                    Text("Tipo")
                } footer: {
                    Text("El tipo de transacción (ingreso o gasto) no se puede modificar.")
                }

                Section("Monto") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }

                Section("Tarjeta (opcional)") {
                    if viewModel.cards.isEmpty {
                        Text("No hay tarjetas.")
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
                        Text("No hay categorías disponibles.")
                            .foregroundStyle(.secondary)
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
            .navigationTitle("Editar Transacción")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedCategory = viewModel.category(for: transaction.categoryId)
                selectedCard = viewModel.card(for: transaction.cardId)
            }
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
                Text(viewModel.errorMessage ?? "No se pudo actualizar la transacción.")
            }
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

        var updated = transaction
        updated.amount = amount
        updated.categoryId = category.id
        updated.cardId = selectedCard?.id
        updated.date = date
        updated.note = note.isEmpty ? nil : note
        updated.updatedAt = Date()
        // type permanece igual (no editable)

        Task {
            await viewModel.updateTransaction(updated)
            if viewModel.errorMessage == nil {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    EditTransactionView(transaction: Transaction(
        amount: 50.00,
        categoryId: UUID(),
        date: Date(),
        note: "Prueba",
        type: .expense
    ))
    .environment(TransactionViewModel())
}
