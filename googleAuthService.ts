import { GoogleUser, Appointment, Client, Lead, Expense } from './types.ts';
import { Translations } from './i18n.ts';
import * as db from './data/mockDB.ts';


// ---
// CRITICAL SECURITY NOTICE FOR DEVELOPERS
// ---
// The API credentials (GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET) are highly sensitive.
// They should NEVER be hardcoded or exposed in any frontend code (JavaScript, HTML, etc.).
//
// **Correct Implementation:**
// 1.  The `GOOGLE_CLIENT_ID` can be used in the frontend to initiate the OAuth flow.
// 2.  The `GOOGLE_CLIENT_SECRET` MUST reside on a secure backend server and nowhere else.
// 3.  The OAuth 2.0 flow involves redirecting the user to Google. After consent, Google
//     redirects back to your app with an authorization `code`.
// 4.  Your frontend sends this `code` to YOUR backend.
// 5.  Your backend server then securely exchanges the `code`, `CLIENT_ID`, and `CLIENT_SECRET`
//     with Google's token endpoint to get an `access_token`.
// 6.  The backend then manages the session for the user.
//
// The code below simulates this flow but does not implement a backend for simplicity.
// The provided user credentials are NOT used and are only referenced in comments
// to illustrate where they fit in a production-ready architecture.
//
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID; // e.g., '37344...apps.googleusercontent.com'
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET; // Should ONLY be used on a server.


const GOOGLE_TOKEN_KEY = 'google-auth-token';
const GOOGLE_USER_KEY = 'google-user';


// --- Simulated Google API Client ---
// In a real app, you would use the official Google API client library (gapi).
// This class simulates its structure and behavior for demonstration.

class GoogleApiClient {
    private accessToken: string | null = null;

    constructor() {
        this.accessToken = localStorage.getItem(GOOGLE_TOKEN_KEY);
    }

    setToken(token: string) {
        this.accessToken = token;
        localStorage.setItem(GOOGLE_TOKEN_KEY, token);
    }

    clearToken() {
        this.accessToken = null;
        localStorage.removeItem(GOOGLE_TOKEN_KEY);
    }

    isAuthenticated(): boolean {
        return !!this.accessToken;
    }

    // --- Simulated API Namespaces ---
    // These methods would use the accessToken to make real API calls.
    
    calendar = {
        events: {
            insert: async (calendarId: string, event: any): Promise<any> => {
                if (!this.isAuthenticated()) throw new Error("401 Unauthorized: Missing Google API Token.");
                console.log(`[Google API Sim] POST to calendar.events.insert for calendar '${calendarId}':`, event);
                await new Promise(res => setTimeout(res, 100)); // Simulate network latency
                return { status: 'confirmed', htmlLink: `https://calendar.google.com/event?id=${Date.now()}` };
            }
        }
    };

    drive = {
        files: {
            create: async (metadata: any, media: any): Promise<any> => {
                 if (!this.isAuthenticated()) throw new Error("401 Unauthorized: Missing Google API Token.");
                 console.log(`[Google API Sim] POST to drive.files.create: ${metadata.name}`, { metadata, body: media.body });
                 await new Promise(res => setTimeout(res, 500));
                 return { id: `drive_${Date.now()}`, name: metadata.name };
            }
        }
    };
    
    sheets = {
        spreadsheets: {
            create: async (resource: any): Promise<any> => {
                if (!this.isAuthenticated()) throw new Error("401 Unauthorized: Missing Google API Token.");
                console.log(`[Google API Sim] POST to sheets.spreadsheets.create:`, resource);
                await new Promise(res => setTimeout(res, 400));
                const id = `sheet_${Date.now()}`;
                return { spreadsheetId: id, spreadsheetUrl: `https://docs.google.com/spreadsheets/d/${id}` , properties: { title: resource.properties.title }};
            },
            batchUpdate: async (spreadsheetId: string, resource: any): Promise<any> => {
                if (!this.isAuthenticated()) throw new Error("401 Unauthorized: Missing Google API Token.");
                console.log(`[Google API Sim] POST to sheets.spreadsheets.batchUpdate for sheet ${spreadsheetId} with ${resource.requests.length} requests.`);
                 await new Promise(res => setTimeout(res, 600));
                return { spreadsheetId, replies: resource.requests.map(() => ({ addSheet: { properties: { sheetId: Date.now() } } })) };
            },
            values: {
                update: async (params: any): Promise<any> => {
                    if (!this.isAuthenticated()) throw new Error("401 Unauthorized: Missing Google API Token.");
                    console.log(`[Google API Sim] POST to sheets.spreadsheets.values.update for sheet ${params.spreadsheetId} at range ${params.range} with ${params.resource.values.length} rows.`);
                    await new Promise(res => setTimeout(res, 600));
                    return { spreadsheetId: params.spreadsheetId, updatedRows: params.resource.values.length };
                }
            }
        }
    }
}

const apiClient = new GoogleApiClient();


// --- Authentication Functions ---
const mockGoogleUser: GoogleUser = {
    email: 'admin.manager@pet-tech.io',
    name: 'Admin Manager',
    picture: 'https://i.pravatar.cc/150?u=admin.manager@pet-tech.io'
};

export const getMockUser = (): GoogleUser => {
    return mockGoogleUser;
};

export const signIn = (): GoogleUser => {
    // This function simulates the final step of a successful OAuth 2.0 flow.
    console.log(`[Simulated OAuth] Using placeholder GOOGLE_CLIENT_ID to initiate flow.`);
    console.warn(`[Security Warning] The GOOGLE_CLIENT_SECRET is a secret and should ONLY ever be handled by a secure backend server, never in frontend code.`);

    const fakeToken = `fake-token-${Date.now()}`;
    apiClient.setToken(fakeToken);
    localStorage.setItem(GOOGLE_USER_KEY, JSON.stringify(mockGoogleUser));
    return mockGoogleUser;
};

export const signOut = (): void => {
    apiClient.clearToken();
    localStorage.removeItem(GOOGLE_USER_KEY);
};

export const getCurrentUser = (): GoogleUser | null => {
    if (!apiClient.isAuthenticated()) return null;
    const userStr = localStorage.getItem(GOOGLE_USER_KEY);
    return userStr ? JSON.parse(userStr) : null;
};


// --- Service Integration Functions ---

export const syncCalendar = async (onProgress: (messageKey: keyof Translations) => void): Promise<{ message: string }> => {
    if (!apiClient.isAuthenticated()) throw new Error("Error: Not authenticated with Google.");

    const unsynced = await db.getUnsyncedAppointments();
    if (unsynced.length === 0) {
        return { message: 'No hay nuevas citas para sincronizar.' };
    }

    onProgress('dashboard.google.inserting_events');
    for (const app of unsynced) {
        const client = await db.getClientById(app.clientId);
        // Assuming 1 hour duration for simplicity
        const startTime = new Date(`${app.date}T${app.time}:00`);
        const endTime = new Date(startTime.getTime() + 60 * 60 * 1000);

        const event = {
            summary: `Cita: ${app.service} para ${app.petName}`,
            location: app.address,
            description: `Cliente: ${client?.name}\nTeléfono: ${client?.phone}`,
            start: { dateTime: startTime.toISOString(), timeZone: 'America/Bogota' },
            end: { dateTime: endTime.toISOString(), timeZone: 'America/Bogota' },
            attendees: [{ email: client?.email }],
        };
        await apiClient.calendar.events.insert('primary', event);
    }
    
    await db.markAppointmentsAsSynced();
    return { message: `${unsynced.length} cita(s) sincronizada(s) con Google Calendar.` };
};

export const backupClientDataToDrive = async (onProgress: (messageKey: keyof Translations) => void): Promise<{ message: string }> => {
    if (!apiClient.isAuthenticated()) throw new Error("Error: Not authenticated with Google.");

    const clients = await db.getClients();
    let uploadedCount = 0;

    for (const client of clients) {
        onProgress('dashboard.google.uploading_client_report'); // This message will flash for each client. Better to have a more specific message if needed.
        
        const clientData = JSON.stringify(client, null, 2);
        const fileName = `reporte-cliente-${client.name.replace(/\s/g, '_')}-${client.id}.json`;
        
        const fileMetadata = { name: fileName, parents: ['PET_TECH_CONNECT_REPORTS'] }; // Simulate saving to a specific folder
        const media = { mimeType: 'application/json', body: clientData };
        
        await apiClient.drive.files.create(fileMetadata, media);
        uploadedCount++;
    }
    
    return { message: `${uploadedCount} reportes de clientes guardados en Google Drive.` };
};

export const exportToSheets = async (onProgress: (messageKey: keyof Translations) => void): Promise<{ message: string }> => {
     if (!apiClient.isAuthenticated()) throw new Error("Error: Not authenticated with Google.");

    onProgress('dashboard.google.creating_sheet');

    const [appointments, clients] = await Promise.all([db.getAppointments(), db.getClients()]);
    
    const spreadsheet = await apiClient.sheets.spreadsheets.create({
        properties: { title: `Reporte de Operaciones Pet-Tech - ${new Date().toLocaleDateString()}` }
    });
    
    // Create two sheets: "Citas" and "Clientes"
    await apiClient.sheets.spreadsheets.batchUpdate(spreadsheet.spreadsheetId, {
        requests: [
            { addSheet: { properties: { title: "Citas" } } },
            { addSheet: { properties: { title: "Clientes" } } },
            { deleteSheet: { sheetId: 0 } } // Delete the default "Sheet1"
        ]
    });

    onProgress('dashboard.google.writing_appointments');
    const appointmentHeaders = ["ID Cita", "Fecha", "Hora", "ID Cliente", "Nombre Mascota", "Servicio", "Estado", "Pago", "Sincronizado"];
    const appointmentRows = appointments.map(app => [ app.id, app.date, app.time, app.clientId, app.petName, app.service, app.status, app.paymentStatus, String(app.syncedToGoogle) ]);
    await apiClient.sheets.spreadsheets.values.update({
        spreadsheetId: spreadsheet.spreadsheetId,
        range: 'Citas!A1',
        valueInputOption: 'RAW',
        resource: { values: [appointmentHeaders, ...appointmentRows] },
    });

    onProgress('dashboard.google.writing_clients');
    const clientHeaders = ["ID Cliente", "Nombre", "Email", "Teléfono", "Dirección", "Miembro Desde", "Mascota", "Raza"];
    const clientRows = clients.map(c => [ c.id, c.name, c.email, c.phone, c.address, c.memberSince, c.pet.name, c.pet.breed ]);
    await apiClient.sheets.spreadsheets.values.update({
        spreadsheetId: spreadsheet.spreadsheetId,
        range: 'Clientes!A1',
        valueInputOption: 'RAW',
        resource: { values: [clientHeaders, ...clientRows] },
    });

    return { message: `${appointments.length} citas y ${clients.length} clientes exportados a una nueva hoja de cálculo.` };
};