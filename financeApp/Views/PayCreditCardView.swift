//
//  PayCreditCardView.swift
//  FinanceFlow
//
//  Vista para pagar una tarjeta de crédito: monto y fuente de pago (tarjeta/efectivo).
//

import SwiftUI

struct PayCreditCardView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let creditCard: Card

    @State private var amountText = ""
    @State private var selectedSourceCard: Card?
    @State private var showingError = false

    private var balance: Decimal {
        viewModel.creditCardBalance(card: creditCard)
    }

    private var sourceCards: [Card] {
        viewModel.paymentSourceCards
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: creditCard.type.iconName)
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(creditCard.name)
                                .font(.headline)
                            Text("Deuda actual: \(CurrencyFormatter.shared.format(balance, currency: viewModel.selectedCurrency))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tarjeta a pagar")
                }

                Section("Monto a pagar") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                    if balance > 0 {
                        Button {
                            amountText = CurrencyFormatter.shared.formatForInput(balance, currency: viewModel.selectedCurrency)
                        } label: {
                            Label("Pagar saldo completo", systemImage: "checkmark.circle")
                        }
                    }
                }

                Section("Pagar desde") {
                    if sourceCards.isEmpty {
                        Text("No hay tarjetas de débito o efectivo. Agrega una desde Gestionar Tarjetas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Origen del pago", selection: $selectedSourceCard) {
                            Text("Seleccionar").tag(nil as Card?)
                            ForEach(sourceCards) { card in
                                Label(card.name, systemImage: card.type.iconName)
                                    .tag(card as Card?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pagar Tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pagar") {
                        payCard()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                if selectedSourceCard == nil, let first = sourceCards.first {
                    selectedSourceCard = first
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "No se pudo registrar el pago.")
            }
        }
    }

    private var isFormValid: Bool {
        guard let amount = CurrencyFormatter.shared.parse(amountText, currency: viewModel.selectedCurrency),
              amount > 0 else { return false }
        return selectedSourceCard != nil && viewModel.creditCardPaymentCategory != nil
    }

    private func payCard() {
        guard let amount = CurrencyFormatter.shared.parse(amountText, currency: viewModel.selectedCurrency),
              amount > 0,
              let sourceCard = selectedSourceCard,
              let category = viewModel.creditCardPaymentCategory else { return }

        let transaction = Transaction(
            amount: amount,
            categoryId: category.id,
            cardId: sourceCard.id,
            creditCardPaidId: creditCard.id,
            date: Date(),
            note: "Pago a \(creditCard.name)",
            type: .expense,
            fixedVariable: .variable
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
    PayCreditCardView(creditCard: Card(name: "Visa Principal", type: .credit, creditLimit: 5_000_000, cutoffDay: 15, paymentDueDay: 25))
        .environment(TransactionViewModel())
}
