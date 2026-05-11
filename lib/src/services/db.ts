import { openDB, type IDBPDatabase } from 'idb';

const DB_NAME = 'aios-db';
const DB_VERSION = 1;

interface ConversationRow {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
}

interface MessageRow {
  id: string;
  conversationId: string;
  role: string;
  content: string;
  createdAt: number;
  toolName?: string;
  toolArgs?: string;
  toolResult?: string;
}

interface AiosDB {
  conversations: ConversationRow;
  messages: MessageRow;
  notes: { key: string; value: string; updatedAt: number };
}

let dbInstance: IDBPDatabase<AiosDB> | null = null;

export async function getDB(): Promise<IDBPDatabase<AiosDB>> {
  if (dbInstance) return dbInstance;
  dbInstance = await openDB<AiosDB>(DB_NAME, DB_VERSION, {
    upgrade(db) {
      if (!db.objectStoreNames.contains('conversations')) {
        db.createObjectStore('conversations', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('messages')) {
        const store = db.createObjectStore('messages', { keyPath: 'id' });
        store.createIndex('conversationId', 'conversationId');
      }
      if (!db.objectStoreNames.contains('notes')) {
        db.createObjectStore('notes', { keyPath: 'key' });
      }
    },
  });
  return dbInstance;
}

export type { ConversationRow, MessageRow };
