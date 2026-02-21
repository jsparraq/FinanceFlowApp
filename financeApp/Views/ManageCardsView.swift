//
//  ManageCardsView.swift
//  FinanceFlow
//
//  Vista para gestionar tarjetas: listar, agregar, editar y eliminar.
//

import SwiftUI

struct ManageCardsView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @State private var showingAddCard = false
    @State private var cardToEdit: Card?
    @State private var cardToDelete: Card?
    @State private var cardToPay: Card?
    @State private var showingDeleteConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    /// Tarjetas ordenadas: Efectivo siempre primero, luego las del usuario
    private var sortedCards: [Card] {
        let efectivo = viewModel.cards.filter { $0.isSystemEfectivo }
        let others = viewModel.cards.filter { !$0.isSystemEfectivo }
        return efectivo + others
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Botón agregar tarjeta
                addCardButton

                // Grid de tarjetas (2 por fila)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(sortedCards) { card in
                        CardTile(
                            card: card,
                            onTap: { cardToEdit = card },
                            onDelete: {
                                guard !card.isSystemEfectivo else { return }
                                cardToDelete = card
                                showingDeleteConfirmation = true
                            },
                            onPay: card.isCredit ? { cardToPay = card } : nil,
                            canDelete: !card.isSystemEfectivo
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Gestionar Tarjetas")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCard) {
            AddCardView()
        }
        .sheet(item: $cardToEdit) { card in
            EditCardView(card: card)
        }
        .sheet(item: $cardToPay) { card in
            PayCreditCardView(creditCard: card)
        }
        .alert("Eliminar tarjeta", isPresented: $showingDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {
                cardToDelete = nil
            }
            Button("Eliminar", role: .destructive) {
                if let card = cardToDelete {
                    Task {
                        await viewModel.deleteCard(card)
                    }
                }
                cardToDelete = nil
            }
        } message: {
            if let card = cardToDelete {
                Text("¿Eliminar \"\(card.name)\"? Esta acción no se puede deshacer.")
            }
        }
    }

    private var addCardButton: some View {
        Button {
            showingAddCard = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Agregar tarjeta")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CardTile

private struct CardTile: View {
    @Environment(TransactionViewModel.self) private var viewModel
    let card: Card
    let onTap: () -> Void
    let onDelete: () -> Void
    let onPay: (() -> Void)?
    let canDelete: Bool

    private var creditBalance: Decimal {
        card.isCredit ? viewModel.creditCardBalance(card: card) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: card.type.iconName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                Spacer()
                if canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }

            Text(card.name)
                .font(.headline)
                .lineLimit(2)

            Text(card.type.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            if card.isCredit {
                Text("Se debe: \(CurrencyFormatter.shared.format(creditBalance, currency: viewModel.selectedCurrency))")
                    .font(.subheadline)
                    .foregroundStyle(creditBalance > 0 ? .red : .secondary)
            }

            if card.isCredit, let onPay {
                Button {
                    onPay()
                } label: {
                    Label("Pagar", systemImage: "creditcard.and.1234")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 120)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    NavigationStack {
        ManageCardsView()
            .environment(TransactionViewModel())
    }
}
