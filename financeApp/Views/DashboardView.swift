//
//  DashboardView.swift
//  FinanceFlow
//
//  Vista principal con resumen de saldo y gráficos del mes actual (Swift Charts).
//

import SwiftUI
import Charts

enum DashboardChartType: String, CaseIterable {
    case bar = "Barras"
    case pie = "Pastel"
}

struct DashboardView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @State private var chartType: DashboardChartType = .bar

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Saldo total
                balanceCard

                // Gestionar tarjetas
                manageCardsButton

                // Resumen del mes (ingresos vs gastos)
                summaryCards

                // Selector de tipo de gráfica
                chartTypePicker

                // Gráfico del mes actual
                chartSection
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

    private var manageCardsButton: some View {
        NavigationLink {
            ManageCardsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Gestionar tarjetas")
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

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Ingresos (mes)",
                amount: viewModel.totalIncomeCurrentMonth,
                color: .green
            )
            summaryCard(
                title: "Gastos (mes)",
                amount: viewModel.totalExpensesCurrentMonth,
                color: .red
            )
        }
    }

    private var chartTypePicker: some View {
        Picker("Tipo de gráfica", selection: $chartType) {
            ForEach(DashboardChartType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
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

    private var currentMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentMonthTitle)
                .font(.headline)

            switch chartType {
            case .bar:
                barChartView
            case .pie:
                pieChartsView
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var barChartView: some View {
        let data = viewModel.barChartDataCurrentMonth.filter {
            NSDecimalNumber(decimal: $0.amount).doubleValue != 0
        }
        return Group {
            if data.isEmpty {
                Text("Sin transacciones este mes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Día", item.day),
                        y: .value("Monto", NSDecimalNumber(decimal: item.amount).doubleValue),
                        stacking: .unstacked
                    )
                    .foregroundStyle(by: .value("Tipo", item.isIncome ? "Ingresos" : "Egresos"))
                    .position(by: .value("Tipo", item.isIncome ? "Ingresos" : "Egresos"))
                }
                .chartForegroundStyleScale([
                    "Ingresos": Color.green.gradient,
                    "Egresos": Color.red.gradient
                ])
                .chartLegend(position: .bottom, spacing: 8)
                .frame(height: 220)
            }
        }
    }

    private func categoryLegend(slices: [TransactionViewModel.CategorySlice]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.name)
                        .font(.subheadline)
                    Spacer()
                    Text(CurrencyFormatter.shared.format(slice.amount, currency: viewModel.selectedCurrency))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.top, 4)
    }

    private var pieChartsView: some View {
        VStack(spacing: 24) {
            // Gráfico de ingresos por categoría
            if viewModel.incomeByCategoryCurrentMonth.isEmpty && viewModel.expensesByCategoryCurrentMonth.isEmpty {
                Text("Sin transacciones este mes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                if !viewModel.incomeByCategoryCurrentMonth.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingresos por categoría")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.secondary)
                        Chart(viewModel.incomeByCategoryCurrentMonth) { slice in
                            SectorMark(
                                angle: .value("Monto", NSDecimalNumber(decimal: slice.amount).doubleValue),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Categoría", slice.name))
                            .cornerRadius(4)
                        }
                        .chartForegroundStyleScale(domain: viewModel.incomeByCategoryCurrentMonth.map(\.name), range: viewModel.incomeByCategoryCurrentMonth.map { $0.color.gradient })
                        .frame(height: 160)
                        categoryLegend(slices: viewModel.incomeByCategoryCurrentMonth)
                    }
                }

                if !viewModel.expensesByCategoryCurrentMonth.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Egresos por categoría")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.secondary)
                        Chart(viewModel.expensesByCategoryCurrentMonth) { slice in
                            SectorMark(
                                angle: .value("Monto", NSDecimalNumber(decimal: slice.amount).doubleValue),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Categoría", slice.name))
                            .cornerRadius(4)
                        }
                        .chartForegroundStyleScale(domain: viewModel.expensesByCategoryCurrentMonth.map(\.name), range: viewModel.expensesByCategoryCurrentMonth.map { $0.color.gradient })
                        .frame(height: 160)
                        categoryLegend(slices: viewModel.expensesByCategoryCurrentMonth)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environment(TransactionViewModel())
    }
}
