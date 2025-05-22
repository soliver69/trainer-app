import SwiftUI
import Foundation

// MARK: - Data Models
struct Client: Identifiable, Codable {
    let id = UUID()
    var name: String
    var phone: String
    var email: String
    var sessionsRemaining: Int
    var totalDeposit: Double
    var pricePerSession: Double
    var dateCreated: Date
    var isActive: Bool
    
    var sessionsUsed: Int {
        let totalSessions = Int(totalDeposit / pricePerSession)
        return totalSessions - sessionsRemaining
    }
}

struct WorkoutSession: Identifiable, Codable {
    let id = UUID()
    var clientId: UUID
    var date: Date
    var exercises: String
    var notes: String
    var clientSignature: String // In real app, this would be signature data
    var isCompleted: Bool
    var duration: TimeInterval
}

struct Appointment: Identifiable, Codable {
    let id = UUID()
    var clientId: UUID
    var date: Date
    var duration: TimeInterval
    var notes: String
    var isConfirmed: Bool
}

// MARK: - Data Manager
class TrainerDataManager: ObservableObject {
    @Published var clients: [Client] = []
    @Published var workoutSessions: [WorkoutSession] = []
    @Published var appointments: [Appointment] = []
    
    init() {
        loadData()
    }
    
    // Client Management
    func addClient(_ client: Client) {
        clients.append(client)
        saveData()
    }
    
    func updateClient(_ client: Client) {
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients[index] = client
            saveData()
        }
    }
    
    func deleteClient(_ client: Client) {
        clients.removeAll { $0.id == client.id }
        workoutSessions.removeAll { $0.clientId == client.id }
        appointments.removeAll { $0.clientId == client.id }
        saveData()
    }
    
    // Workout Session Management
    func addWorkoutSession(_ session: WorkoutSession) {
        workoutSessions.append(session)
        // Deduct one session from client
        if let clientIndex = clients.firstIndex(where: { $0.id == session.clientId }) {
            clients[clientIndex].sessionsRemaining -= 1
        }
        saveData()
    }
    
    // Appointment Management
    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
        saveData()
    }
    
    func updateAppointment(_ appointment: Appointment) {
        if let index = appointments.firstIndex(where: { $0.id == appointment.id }) {
            appointments[index] = appointment
            saveData()
        }
    }
    
    // Helper functions
    func getClient(by id: UUID) -> Client? {
        return clients.first { $0.id == id }
    }
    
    func getWorkoutSessions(for client: Client) -> [WorkoutSession] {
        return workoutSessions.filter { $0.clientId == client.id }
    }
    
    func getAppointments(for client: Client) -> [Appointment] {
        return appointments.filter { $0.clientId == client.id }
    }
    
    // Data Persistence (simplified - in real app use Core Data or similar)
    private func saveData() {
        // Save to UserDefaults for simplicity
        if let clientData = try? JSONEncoder().encode(clients) {
            UserDefaults.standard.set(clientData, forKey: "clients")
        }
        if let sessionData = try? JSONEncoder().encode(workoutSessions) {
            UserDefaults.standard.set(sessionData, forKey: "workoutSessions")
        }
        if let appointmentData = try? JSONEncoder().encode(appointments) {
            UserDefaults.standard.set(appointmentData, forKey: "appointments")
        }
    }
    
    private func loadData() {
        if let clientData = UserDefaults.standard.data(forKey: "clients"),
           let decodedClients = try? JSONDecoder().decode([Client].self, from: clientData) {
            self.clients = decodedClients
        }
        if let sessionData = UserDefaults.standard.data(forKey: "workoutSessions"),
           let decodedSessions = try? JSONDecoder().decode([WorkoutSession].self, from: sessionData) {
            self.workoutSessions = decodedSessions
        }
        if let appointmentData = UserDefaults.standard.data(forKey: "appointments"),
           let decodedAppointments = try? JSONDecoder().decode([Appointment].self, from: appointmentData) {
            self.appointments = decodedAppointments
        }
    }
}

// MARK: - Main App
@main
struct PersonalTrainerApp: App {
    @StateObject private var dataManager = TrainerDataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    
    var body: some View {
        TabView {
            ClientListView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Clients")
                }
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }
            
            WorkoutHistoryView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Workouts")
                }
        }
    }
}

// MARK: - Client List View
struct ClientListView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    @State private var showingAddClient = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.clients.filter { $0.isActive }) { client in
                    NavigationLink(destination: ClientDetailView(client: client)) {
                        ClientRowView(client: client)
                    }
                }
                .onDelete(perform: deleteClients)
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddClient = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView()
            }
        }
    }
    
    func deleteClients(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let client = dataManager.clients.filter { $0.isActive }[index]
                dataManager.deleteClient(client)
            }
        }
    }
}

// MARK: - Client Row View
struct ClientRowView: View {
    let client: Client
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.name)
                .font(.headline)
            Text(client.phone)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Sessions: \(client.sessionsRemaining)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(client.sessionsRemaining > 0 ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                Spacer()
                
                Text("$\(client.totalDeposit, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Client View
struct AddClientView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var depositAmount = ""
    @State private var pricePerSession = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Client Information")) {
                    TextField("Name", text: $name)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                }
                
                Section(header: Text("Payment Information")) {
                    TextField("Deposit Amount", text: $depositAmount)
                        .keyboardType(.decimalPad)
                    TextField("Price Per Session", text: $pricePerSession)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Client")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveClient()
                }
                .disabled(name.isEmpty || depositAmount.isEmpty || pricePerSession.isEmpty)
            )
        }
    }
    
    func saveClient() {
        guard let deposit = Double(depositAmount),
              let sessionPrice = Double(pricePerSession) else { return }
        
        let totalSessions = Int(deposit / sessionPrice)
        
        let client = Client(
            name: name,
            phone: phone,
            email: email,
            sessionsRemaining: totalSessions,
            totalDeposit: deposit,
            pricePerSession: sessionPrice,
            dateCreated: Date(),
            isActive: true
        )
        
        dataManager.addClient(client)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Client Detail View
struct ClientDetailView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    let client: Client
    @State private var showingAddWorkout = false
    
    var body: some View {
        List {
            Section(header: Text("Client Info")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone: \(client.phone)")
                    Text("Email: \(client.email)")
                    Text("Sessions Remaining: \(client.sessionsRemaining)")
                    Text("Total Deposit: $\(client.totalDeposit, specifier: "%.2f")")
                    Text("Price per Session: $\(client.pricePerSession, specifier: "%.2f")")
                }
            }
            
            Section(header: Text("Recent Workouts")) {
                let sessions = dataManager.getWorkoutSessions(for: client)
                    .sorted { $0.date > $1.date }
                    .prefix(5)
                
                if sessions.isEmpty {
                    Text("No workouts recorded")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(sessions), id: \.id) { session in
                        WorkoutRowView(session: session)
                    }
                }
            }
        }
        .navigationTitle(client.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Workout") {
                    showingAddWorkout = true
                }
                .disabled(client.sessionsRemaining <= 0)
            }
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutView(client: client)
        }
    }
}

// MARK: - Add Workout View
struct AddWorkoutView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    @Environment(\.presentationMode) var presentationMode
    
    let client: Client
    @State private var exercises = ""
    @State private var notes = ""
    @State private var clientSignature = ""
    @State private var duration: TimeInterval = 3600 // 1 hour default
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Workout Details")) {
                    TextField("Exercises Performed", text: $exercises, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section(header: Text("Duration")) {
                    Picker("Duration", selection: $duration) {
                        Text("30 min").tag(TimeInterval(1800))
                        Text("45 min").tag(TimeInterval(2700))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                        Text("2 hours").tag(TimeInterval(7200))
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Client Sign-off")) {
                    TextField("Client Name (Signature)", text: $clientSignature)
                    Text("By signing above, the client confirms completion of this workout session.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Record Workout")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveWorkout()
                }
                .disabled(exercises.isEmpty || clientSignature.isEmpty)
            )
        }
    }
    
    func saveWorkout() {
        let session = WorkoutSession(
            clientId: client.id,
            date: Date(),
            exercises: exercises,
            notes: notes,
            clientSignature: clientSignature,
            isCompleted: true,
            duration: duration
        )
        
        dataManager.addWorkoutSession(session)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Workout Row View
struct WorkoutRowView: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.date, style: .date)
                    .font(.headline)
                Spacer()
                Text("\(Int(session.duration/60)) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(session.exercises)
                .font(.subheadline)
                .lineLimit(2)
            
            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    @State private var selectedDate = Date()
    @State private var showingAddAppointment = false
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                List {
                    let appointmentsForDate = dataManager.appointments
                        .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
                        .sorted { $0.date < $1.date }
                    
                    if appointmentsForDate.isEmpty {
                        Text("No appointments scheduled")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appointmentsForDate) { appointment in
                            AppointmentRowView(appointment: appointment)
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAppointment = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAppointment) {
                AddAppointmentView(selectedDate: selectedDate)
            }
        }
    }
}

// MARK: - Add Appointment View
struct AddAppointmentView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    @Environment(\.presentationMode) var presentationMode
    
    let selectedDate: Date
    @State private var selectedClient: Client?
    @State private var appointmentTime = Date()
    @State private var duration: TimeInterval = 3600
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appointment Details")) {
                    Picker("Client", selection: $selectedClient) {
                        Text("Select Client").tag(Client?.none)
                        ForEach(dataManager.clients.filter { $0.isActive }) { client in
                            Text(client.name).tag(Client?.some(client))
                        }
                    }
                    
                    DatePicker("Time", selection: $appointmentTime, displayedComponents: .hourAndMinute)
                    
                    Picker("Duration", selection: $duration) {
                        Text("30 min").tag(TimeInterval(1800))
                        Text("45 min").tag(TimeInterval(2700))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Appointment notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveAppointment()
                }
                .disabled(selectedClient == nil)
            )
        }
    }
    
    func saveAppointment() {
        guard let client = selectedClient else { return }
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: appointmentTime)
        
        var finalDate = DateComponents()
        finalDate.year = dateComponents.year
        finalDate.month = dateComponents.month
        finalDate.day = dateComponents.day
        finalDate.hour = timeComponents.hour
        finalDate.minute = timeComponents.minute
        
        let appointment = Appointment(
            clientId: client.id,
            date: Calendar.current.date(from: finalDate) ?? Date(),
            duration: duration,
            notes: notes,
            isConfirmed: false
        )
        
        dataManager.addAppointment(appointment)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Appointment Row View
struct AppointmentRowView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    let appointment: Appointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let client = dataManager.getClient(by: appointment.clientId) {
                    Text(client.name)
                        .font(.headline)
                } else {
                    Text("Unknown Client")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Text(appointment.date, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(appointment.duration/60)) minutes")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !appointment.notes.isEmpty {
                Text(appointment.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Workout History View
struct WorkoutHistoryView: View {
    @EnvironmentObject var dataManager: TrainerDataManager
    
    var body: some View {
        NavigationView {
            List {
                let allSessions = dataManager.workoutSessions
                    .sorted { $0.date > $1.date }
                
                if allSessions.isEmpty {
                    Text("No workout sessions recorded")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(allSessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if let client = dataManager.getClient(by: session.clientId) {
                                    Text(client.name)
                                        .font(.headline)
                                } else {
                                    Text("Unknown Client")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                                
                                Text(session.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            WorkoutRowView(session: session)
                        }
                    }
                }
            }
            .navigationTitle("Workout History")
        }
    }
}
