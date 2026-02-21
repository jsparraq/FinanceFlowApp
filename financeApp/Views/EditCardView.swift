//
//  EditCardView.swift
//  FinanceFlow
//
//  Formulario para editar una tarjeta existente.
//  Se puede modificar: nombre, cupo máximo (solo crédito).
//  El tipo de tarjeta no se puede modificar.
//

import SwiftUI

struct EditCardView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let card: Card

    @State private var name: String = ""
    @State private var creditLimitText: String = ""
    @State private var cutoffDay: Int = 15
    @State private var paymentDueDay: Int = 25
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de tarjeta") {
                    HStack {
                        Image(systemName: card.type.iconName)
                            .foregroundStyle(.secondary)
                        Text(card.type.displayName)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Nombre") {
                    TextField("Ej: Visa principal, Nequi, etc.", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                }

                if card.isCredit {
                    Section {
                        TextField("0", text: $creditLimitText)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                    } header: {
                        Text("Cupo máximo")
                    } footer: {
                        Text("Monto máximo que puedes gastar con esta tarjeta.")
                    }

                    Section {
                        Picker("Fecha de corte", selection: $cutoffDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("Día \(day)").tag(day)
                            }
                        }
                        Picker("Fecha límite de pago", selection: $paymentDueDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("Día \(day)").tag(day)
                            }
                        }
                    } header: {
                        Text("Fechas de facturación")
                    } footer: {
                        Text("Fecha de corte: día en que cierra el ciclo. Fecha límite de pago: día hasta el cual debes pagar.")
                    }
                }
            }
            .navigationTitle("Editar Tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                name = card.name
                if let limit = card.creditLimit {
                    creditLimitText = CurrencyFormatter.shared.formatForInput(limit, currency: viewModel.selectedCurrency)
                }
                cutoffDay = card.cutoffDay ?? 15
                paymentDueDay = card.paymentDueDay ?? 25
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveCard()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "No se pudo actualizar la tarjeta.")
            }
        }
    }

    private var isFormValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if card.isCredit {
            guard let limit = CurrencyFormatter.shared.parse(creditLimitText, currency: viewModel.selectedCurrency),
                  limit > 0 else { return false }
        }

        return true
    }

    private func saveCard() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var creditLimit: Decimal? = nil
        if card.isCredit,
           let limit = CurrencyFormatter.shared.parse(creditLimitText, currency: viewModel.selectedCurrency),
           limit > 0 {
            creditLimit = limit
        }

        var updatedCard = card
        updatedCard.name = trimmed
        updatedCard.creditLimit = creditLimit
        if card.isCredit {
            updatedCard.cutoffDay = cutoffDay
            updatedCard.paymentDueDay = paymentDueDay
        }
        updatedCard.updatedAt = Date()

        Task {
            await viewModel.updateCard(updatedCard)
            if viewModel.errorMessage == nil {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    EditCardView(card: Card(name: "Visa Principal", type: .credit, creditLimit: 5000000, cutoffDay: 15, paymentDueDay: 25))
        .environment(TransactionViewModel())
}
