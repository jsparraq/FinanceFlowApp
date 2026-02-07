//
//  DashboardView.swift
//  FinanceFlow
//
//  Vista principal con resumen de saldo y gráfico simple (Swift Charts).
//

import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(TransactionViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Saldo total
                balanceCard

                // Resumen (ingresos vs gastos)
                summaryCards

                // Gráfico de transacciones por día
                if !viewModel.transactionsByDate.isEmpty {
                    chartSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("FinanceFlow")
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saldo Total")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(CurrencyFormatter.shared.format(viewModel.totalBalance, currency: viewModel.selectedCurrency))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(viewModel.totalBalance >= 0 ? .primary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Ingresos",
                amount: viewModel.totalIncome,
                color: .green
            )
            summaryCard(
                title: "Gastos",
                amount: viewModel.totalExpenses,
                color: .red
            )
        }
    }

    private func summaryCard(title: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.shared.format(amount, currency: viewModel.selectedCurrency))
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actividad Reciente")
                .font(.headline)

            Chart(viewModel.transactionsByDate.prefix(7).reversed(), id: \.date) { item in
                BarMark(
                    x: .value("Fecha", item.date, unit: .day),
                    y: .value("Monto", NSDecimalNumber(decimal: item.amount).doubleValue)
                )
                .foregroundStyle(item.amount >= 0 ? Color.green.gradient : Color.red.gradient)
            }
            .frame(height: 180)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environment(TransactionViewModel())
    }
}
