# Arquitectura de FinanceFlow

Documento de referencia para entender cómo se conectan los componentes de la aplicación.

---

## Diagrama de capas

```mermaid
flowchart TB
    subgraph UI["Capa de presentación"]
        Views[Views<br/>LoginView, DashboardView, AddTransactionView, etc.]
    end

    subgraph Logic["Capa de lógica"]
        ViewModels[ViewModels<br/>AuthViewModel, TransactionViewModel]
    end

    subgraph Data["Capa de datos"]
        Repo[FinanceRepository]
    end

    subgraph Services["Servicios transversales"]
        Auth[AuthService]
        Gmail[GmailService]
        Encrypt[TransactionEncryptionService]
        Export[TransactionExportService]
    end

    subgraph External["Externos"]
        Supabase[(Supabase)]
        GmailAPI[Gmail API]
    end

    Views --> ViewModels
    ViewModels --> Repo
    ViewModels --> Auth
    ViewModels --> Gmail
    Repo --> Supabase
    Repo --> Encrypt
    Gmail --> GmailAPI
```

---

## Navegación y flujo de pantallas

```mermaid
flowchart TD
    Root[RootView] -->|Autenticado| Content[ContentView]
    Root -->|No autenticado| Login[LoginView]

    Login --> SignUp[SignUpView]

    Content --> Tab1[Tab: Inicio]
    Content --> Tab2[Tab: Transacciones]
    Content --> Tab3[Tab: Más]

    Tab1 --> Dashboard[DashboardView]
    Tab1 --> ManageCards[ManageCardsView]
    Tab1 --> AddCard[AddCardView]
    Tab1 --> EditCard[EditCardView]

    Tab2 --> TransList[TransactionListView]
    Tab2 --> AddTrans[AddTransactionView]
    Tab2 --> EditTrans[EditTransactionView]
    Tab2 --> ImportGmail[ImportFromGmailView]
    Tab2 --> Export[ExportTransactionsView]

    Tab3 --> Settings[Configuración / Cerrar sesión]
```

---

## Dependencias entre servicios

```mermaid
flowchart LR
    subgraph Core["Núcleo"]
        SupabaseClient[SupabaseClientService]
    end

    subgraph Depends["Dependen de Supabase"]
        AuthService[AuthService]
        FinanceRepo[FinanceRepository]
    end

    subgraph AuthProviders["Proveedores de Auth"]
        EmailAuth[EmailPasswordAuthProvider]
        GoogleAuth[GoogleAuthProvider]
    end

    subgraph UsesRepo["Usan FinanceRepository"]
        TransVM[TransactionViewModel]
    end

    subgraph UsesGmail["Usan GmailService"]
        ImportView[ImportFromGmailView]
    end

    SupabaseClient --> AuthService
    SupabaseClient --> FinanceRepo
    AuthService --> EmailAuth
    AuthService --> GoogleAuth
    TransVM --> FinanceRepo
    ImportView --> GmailService[GmailService]
    TransVM --> Encrypt[TransactionEncryptionService]
    FinanceRepo --> Encrypt
```

---

## Flujo de importación desde Gmail (detalle)

```mermaid
sequenceDiagram
    participant U as Usuario
    participant V as ImportFromGmailView
    participant G as GmailService
    participant P as NubankEmailParser
    participant VM as TransactionViewModel
    participant R as FinanceRepository

    U->>V: Selecciona banco, fechas, asunto
    V->>G: fetchMessages(from, subject, after, before)
    G->>G: Gmail API (Bearer token de Google Sign-In)
    G-->>V: [GmailMessage]
    V->>P: parse(snippet)
    P-->>V: PendingImportExpense
    V->>U: Muestra lista para revisar
    U->>V: Confirma / edita montos
    loop Por cada gasto seleccionado
        V->>VM: addTransaction(transaction)
        VM->>R: createTransaction()
        R->>R: Encripta monto
        R-->>VM: OK
    end
```

---

## Modelo de datos (tablas principales)

```mermaid
erDiagram
    users ||--o{ transactions : tiene
    users ||--o{ cards : tiene
    categories ||--o{ transactions : categoriza
    cards ||--o{ transactions : asocia

    transactions {
        uuid id PK
        uuid user_id FK
        uuid category_id FK
        uuid card_id FK
        text amount_encrypted
        date date
        text note
        text type
    }

    cards {
        uuid id PK
        uuid user_id FK
        text name
        text type
        decimal credit_limit
        int cutoff_day
        int payment_due_day
    }

    categories {
        uuid id PK
        text name
        text icon_name
        text color_hex
        text transaction_type
    }
```
