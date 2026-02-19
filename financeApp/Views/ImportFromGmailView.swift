//
//  ImportFromGmailView.swift
//  FinanceFlow
//
//  Importa gastos en batch desde Gmail.
//  El usuario configura filtros, busca correos y confirma cada gasto antes de importar.
//

import SwiftUI

/// Gasto pendiente de importar (editable por el usuario)
struct PendingImportExpense: Identifiable {
    let id = UUID()
    var amount: Decimal
    var note: String
    var date: Date
    var categoryId: UUID
    var cardId: UUID?
    var isIncluded: Bool
    let gmailMessageId: String
}

struct ImportFromGmailView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBank: Bank = .nubank
    @State private var emailFrom = ""
    @State private var subjectFilter = ""
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var validationError: String?
    @State private var isLoading = false
    @State private var apiError: String?
    @State private var pendingExpenses: [PendingImportExpense] = []
    @State private var step: Step = .form
    @State private var isImporting = false

    private enum Step {
        case form
        case confirm
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }

    private var dateRangeValidation: (isValid: Bool, message: String?) {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: endDate)).day ?? 0
        if days < 0 {
            return (false, "La fecha fin debe ser posterior a la fecha inicio")
        }
        if days > 31 {
            return (false, "El rango no puede superar 1 mes (31 días)")
        }
        return (true, nil)
    }

    private var otrosCategoryId: UUID? {
        viewModel.categories.first { $0.name == "Otros" && $0.transactionType == .expense }?.id
    }

    private var expenseCategories: [Category] {
        viewModel.categories.filter { $0.transactionType == .expense }
    }

    /// Gastos existentes (solo tipo expense) para detectar conflictos
    private var existingExpenses: [Transaction] {
        viewModel.transactions.filter { $0.type == .expense }
    }

    /// Detecta si un gasto pendiente entra en conflicto con alguna transacción existente.
    /// Conflicto = mismo monto + mismo día.
    private func conflictingTransaction(for expense: PendingImportExpense) -> Transaction? {
        let calendar = Calendar.current
        let expenseDay = calendar.startOfDay(for: expense.date)
        return existingExpenses.first { existing in
            existing.amount == expense.amount &&
            calendar.isDate(existing.date, inSameDayAs: expenseDay)
        }
    }

    /// Índices de gastos nuevos (sin conflicto)
    private var newExpenseIndices: [Int] {
        pendingExpenses.enumerated().compactMap { index, expense in
            conflictingTransaction(for: expense) == nil ? index : nil
        }
    }

    /// Gastos en conflicto: (índice, transacción existente que coincide)
    private var conflictingExpenseIndices: [(index: Int, existing: Transaction)] {
        pendingExpenses.enumerated().compactMap { index, expense in
            guard let existing = conflictingTransaction(for: expense) else { return nil }
            return (index, existing)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .form:
                    formView
                case .confirm:
                    confirmView
                }
            }
            .navigationTitle("Importar desde Gmail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .confirm ? "Atrás" : "Cerrar") {
                        if step == .confirm {
                            step = .form
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var formView: some View {
        Form {
            Section {
                Picker("Banco", selection: $selectedBank) {
                    ForEach(Bank.allCases) { bank in
                        HStack {
                            Text(bank.displayName)
                            if !bank.hasParser {
                                Text("(próximamente)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                        .tag(bank)
                    }
                }

                TextField("Email remitente", text: $emailFrom)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Subject (palabra o frase)", text: $subjectFilter)

                DatePicker("Fecha inicio", selection: $startDate, displayedComponents: .date)
                DatePicker("Fecha fin", selection: $endDate, in: startDate..., displayedComponents: .date)
            } header: {
                Text("Filtros")
            } footer: {
                Text("El rango de fechas no puede superar 1 mes. El email del remitente y el subject son obligatorios.")
            }

            if let error = validationError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if let error = apiError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    searchExpenses()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                        }
                        Text("Buscar gastos")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isLoading || !selectedBank.hasParser || emailFrom.trimmingCharacters(in: .whitespaces).isEmpty || subjectFilter.trimmingCharacters(in: .whitespaces).isEmpty || !dateRangeValidation.isValid)
            }
        }
    }

    private var confirmView: some View {
        List {
            Section {
                Text("Revisa cada gasto. Los que coinciden con transacciones existentes (mismo monto y fecha) aparecen en \"En conflicto\".")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !newExpenseIndices.isEmpty {
                Section {
                    ForEach(newExpenseIndices, id: \.self) { index in
                        PendingExpenseRow(
                            expense: $pendingExpenses[index],
                            categories: expenseCategories,
                            cards: viewModel.cards,
                            conflictInfo: nil,
                            onDeleteExisting: nil
                        )
                    }
                } header: {
                    Text("Gastos nuevos (\(newExpenseIndices.count))")
                }
            }

            if !conflictingExpenseIndices.isEmpty {
                Section {
                    ForEach(conflictingExpenseIndices, id: \.index) { item in
                        PendingExpenseRow(
                            expense: $pendingExpenses[item.index],
                            categories: expenseCategories,
                            cards: viewModel.cards,
                            conflictInfo: item.existing,
                            onDeleteExisting: {
                                Task { await viewModel.deleteTransaction(item.existing) }
                            }
                        )
                    }
                } header: {
                    Text("En conflicto (\(conflictingExpenseIndices.count))")
                } footer: {
                    Text("Estos gastos coinciden con transacciones ya registradas (mismo monto y fecha). Puedes agregarlos de todos modos, excluirlos, o eliminar la existente.")
                }
            }

            Section {
                Button {
                    importSelected()
                } label: {
                    HStack(spacing: 8) {
                        if isImporting {
                            ProgressView()
                            Text("Importando gastos...")
                        } else {
                            Text("Importar \(pendingExpenses.filter(\.isIncluded).count) gastos")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(pendingExpenses.filter(\.isIncluded).isEmpty || isImporting)
            }
        }
    }

    private func searchExpenses() {
        validationError = nil
        apiError = nil

        let (isValid, message) = dateRangeValidation
        guard isValid else {
            validationError = message
            return
        }

        guard !emailFrom.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "El email remitente es obligatorio"
            return
        }
        guard !subjectFilter.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "El subject es obligatorio"
            return
        }

        guard GmailService.shared.canImportFromGmail() else {
            apiError = GmailServiceError.notSignedInWithGoogle.localizedDescription
            return
        }

        isLoading = true
        Task {
            do {
                let after = dateFormatter.string(from: startDate)
                let before = dateFormatter.string(from: endDate)
                let messages = try await GmailService.shared.fetchMessages(
                    from: emailFrom.trimmingCharacters(in: .whitespaces),
                    subject: subjectFilter.trimmingCharacters(in: .whitespaces),
                    after: after,
                    before: before
                )

                guard let parser = BankParserFactory.parser(for: selectedBank) else {
                    apiError = "Parser no disponible para \(selectedBank.displayName)"
                    isLoading = false
                    return
                }

                let defaultCategoryId = otrosCategoryId ?? expenseCategories.first?.id
                guard let catId = defaultCategoryId else {
                    apiError = "No hay categorías. Agrega al menos una categoría de gastos."
                    isLoading = false
                    return
                }

                var pending: [PendingImportExpense] = []
                for msg in messages {
                    if let parsed = parser.parse(snippet: msg.snippet, internalDateMs: msg.internalDate, messageId: msg.id) {
                        pending.append(PendingImportExpense(
                            amount: parsed.amount,
                            note: parsed.note,
                            date: parsed.date,
                            categoryId: catId,
                            cardId: nil,
                            isIncluded: true,
                            gmailMessageId: parsed.gmailMessageId
                        ))
                    }
                }

                await MainActor.run {
                    pendingExpenses = pending
                    step = .confirm
                    if pending.isEmpty {
                        apiError = "No se encontraron gastos en el formato esperado."
                    }
                }
            } catch {
                await MainActor.run {
                    apiError = error.localizedDescription
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func importSelected() {
        let toImport = pendingExpenses.filter(\.isIncluded)
        guard !toImport.isEmpty else { return }

        isImporting = true
        Task {
            for exp in toImport {
                let tx = Transaction(
                    amount: exp.amount,
                    categoryId: exp.categoryId,
                    cardId: exp.cardId,
                    date: exp.date,
                    note: exp.note.isEmpty ? nil : exp.note,
                    type: .expense
                )
                await viewModel.addTransaction(tx)
            }
            await MainActor.run {
                isImporting = false
                dismiss()
            }
        }
    }
}

// MARK: - Pending Expense Row

private struct PendingExpenseRow: View {
    @Binding var expense: PendingImportExpense
    let categories: [Category]
    let cards: [Card]
    var conflictInfo: Transaction?
    var onDeleteExisting: (() -> Void)?

    var body: some View {
        Section {
            if let existing = conflictInfo {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Coincide con transacción existente")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(existing.note ?? "Sin descripción")
                            .font(.subheadline)
                        Spacer()
                        Text(CurrencyFormatter.shared.format(-existing.amount))
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    if let deleteAction = onDeleteExisting {
                        Button(role: .destructive) {
                            deleteAction()
                        } label: {
                            Label("Eliminar la existente", systemImage: "trash")
                        }
                    }
                }
            }

            Toggle(isOn: $expense.isIncluded) {
                Text(CurrencyFormatter.shared.format(-expense.amount))
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            if expense.isIncluded {
                TextField("Descripción", text: $expense.note)
                    .font(.subheadline)

                DatePicker("Fecha", selection: $expense.date, displayedComponents: .date)

                Picker("Categoría", selection: $expense.categoryId) {
                    ForEach(categories) { cat in
                        Label(cat.name, systemImage: cat.iconName)
                            .tag(cat.id)
                    }
                }
                .pickerStyle(.menu)

                if cards.isEmpty {
                    HStack {
                        Text("Tarjeta")
                        Spacer()
                        Text("No hay tarjetas")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    Picker("Tarjeta", selection: $expense.cardId) {
                        Text("Ninguna").tag(nil as UUID?)
                        ForEach(cards) { card in
                            Label(card.name, systemImage: card.type.iconName)
                                .tag(card.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

#Preview {
    ImportFromGmailView()
        .environment(TransactionViewModel())
}
