import { Language } from './i18n';

// Type declarations for the Web Speech API, which is not yet a W3C standard
// and thus not included in TypeScript's default lib.d.ts files.
interface SpeechRecognition extends EventTarget {
    lang: string;
    continuous: boolean;
    interimResults: boolean;
    onresult: (event: any) => void;
    onerror: (event: any) => void;
    onend: (() => void) | null;
    start: () => void;
    stop: () => void;
    abort: () => void;
}

declare global {
    interface Window {
        SpeechRecognition: { new(): SpeechRecognition };
        webkitSpeechRecognition: { new(): SpeechRecognition };
    }
}


const synthesis = window.speechSynthesis;
const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;

let recognition: SpeechRecognition | null = null;
if (Recognition) {
    recognition = new Recognition();
    recognition.continuous = false;
    recognition.interimResults = false;
}

export const speak = (text: string, lang: Language) => {
    if (!synthesis) return;
    
    // Cancel any previous speech
    synthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = lang;

    // Optional: find a specific voice
    const voices = synthesis.getVoices();
    const voice = voices.find(v => v.lang === lang) || voices.find(v => v.lang.startsWith(lang.split('-')[0]));
    if (voice) {
        utterance.voice = voice;
    }
    
    synthesis.speak(utterance);
};

export const cancel = () => {
    if (synthesis) {
        synthesis.cancel();
    }
};

export const startListening = (lang: Language): Promise<string> => {
    cancel(); // Stop any ongoing speech before listening
    
    return new Promise((resolve, reject) => {
        if (!recognition) {
            return reject("Speech recognition not supported in this browser.");
        }
        
        let resolved = false; // Flag to prevent multiple resolutions

        recognition.lang = lang;
        
        recognition.onresult = (event) => {
            if (resolved) return;
            resolved = true;
            const transcript = event.results[0][0].transcript;
            resolve(transcript);
        };
        
        recognition.onerror = (event) => {
            if (resolved) return;
            resolved = true;
            reject(event.error);
        };
        
        recognition.onend = () => {
            // This is crucial. If 'onresult' hasn't fired (e.g., no speech detected),
            // this ensures the promise resolves with an empty string, preventing it from hanging.
            if (!resolved) {
                resolved = true;
                resolve(""); 
            }
        };

        recognition.start();
    });
};

export const stopListening = () => {
    if (recognition) {
        recognition.stop();
    }
};