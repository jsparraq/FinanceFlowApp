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
    let canDelete: Bool

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

            if card.isCredit, let limit = card.creditLimit {
                Text(CurrencyFormatter.shared.format(limit, currency: viewModel.selectedCurrency))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
