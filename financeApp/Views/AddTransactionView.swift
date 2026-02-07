//
//  AddTransactionView.swift
//  FinanceFlow
//
//  Formulario para agregar transacciones manualmente.
//  Punto de integración: LLM para categorización automática, SMS para importar.
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var selectedCategory: Category?
    @State private var selectedType: TransactionType = .expense
    @State private var date = Date()
    @State private var note = ""
    @State private var showingError = false

    private var filteredCategories: [Category] {
        viewModel.categories.filter { $0.transactionType == selectedType }
    }

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Monto") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }

                Section("Categoría") {
                    Picker("Categoría", selection: $selectedCategory) {
                        Text("Seleccionar").tag(nil as Category?)
                        ForEach(filteredCategories) { category in
                            Label(category.name, systemImage: category.iconName)
                                .tag(category as Category?)
                        }
                    }
                }

                Section("Fecha") {
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                Section("Nota (opcional)") {
                    TextField("Descripción o nota", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                    // TODO: Aquí se integrará el LLM para categorización automática
                    // basada en el texto de la nota (ej: "uber comida" -> Transporte)
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

        let transaction = Transaction(
            amount: amount,
            categoryId: category.id,
            date: date,
            note: note.isEmpty ? nil : note,
            type: selectedType
        )

        Task {
            await viewModel.addTransaction(transaction)
            if viewModel.errorMessage == nil {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    AddTransactionView()
        .environment(TransactionViewModel())
}
