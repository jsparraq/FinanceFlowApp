//
//  AddCardView.swift
//  FinanceFlow
//
//  Formulario para agregar tarjetas (débito o crédito).
//

import SwiftUI

struct AddCardView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedType: CardType = .debit
    @State private var creditLimitText = ""
    @State private var cutoffDay: Int = 15
    @State private var paymentDueDay: Int = 25
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de tarjeta") {
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(CardType.userCreatable) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Nombre") {
                    TextField("Ej: Visa principal, Nequi, etc.", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                }

                if selectedType == .credit {
                    Section {
                        TextField("0", text: $creditLimitText)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                    } header: {
                        Text("Cupo máximo")
                    } footer: {
                        Text("Monto máximo que puedes gastar con esta tarjeta. Te ayudará a saber cuánto te queda disponible.")
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
            .navigationTitle("Nueva Tarjeta")
            .navigationBarTitleDisplayMode(.inline)
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
                Text(viewModel.errorMessage ?? "No se pudo guardar la tarjeta.")
            }
        }
    }

    private var isFormValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if selectedType == .credit {
            guard let limit = CurrencyFormatter.shared.parse(creditLimitText, currency: viewModel.selectedCurrency),
                  limit > 0 else { return false }
        }

        return true
    }

    private func saveCard() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var creditLimit: Decimal? = nil
        if selectedType == .credit,
           let limit = CurrencyFormatter.shared.parse(creditLimitText, currency: viewModel.selectedCurrency),
           limit > 0 {
            creditLimit = limit
        }

        var cutoff: Int? = nil
        var paymentDue: Int? = nil
        if selectedType == .credit {
            cutoff = cutoffDay
            paymentDue = paymentDueDay
        }

        let card = Card(
            name: trimmed,
            type: selectedType,
            creditLimit: creditLimit,
            cutoffDay: cutoff,
            paymentDueDay: paymentDue
        )

        Task {
            await viewModel.addCard(card)
            if viewModel.errorMessage == nil {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    AddCardView()
        .environment(TransactionViewModel())
}
