import { getDB, type ConversationRow, type MessageRow } from './db';

export interface ChatMessage {
  id: string;
  role: string;
  content: string;
  createdAt: number;
  toolName?: string;
  toolArgs?: string;
  toolResult?: string;
}

export interface Conversation {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
}

function rowToConversation(row: ConversationRow): Conversation {
  return { id: row.id, title: row.title, createdAt: row.createdAt, updatedAt: row.updatedAt };
}

function rowToMessage(row: MessageRow): ChatMessage {
  return {
    id: row.id,
    role: row.role,
    content: row.content,
    createdAt: row.createdAt,
    toolName: row.toolName,
    toolArgs: row.toolArgs,
    toolResult: row.toolResult,
  };
}

export const conversationDb = {
  async createConversation(title?: string): Promise<Conversation> {
    const db = await getDB();
    const id = `conv_${Date.now()}`;
    const now = Date.now();
    const row: ConversationRow = { id, title: title ?? '새 대화', createdAt: now, updatedAt: now };
    await db.put('conversations', row);
    return rowToConversation(row);
  },

  async getAllConversations(): Promise<Conversation[]> {
    const db = await getDB();
    const rows = await db.getAll('conversations');
    return rows.sort((a, b) => b.updatedAt - a.updatedAt).map(rowToConversation);
  },

  async deleteConversation(id: string): Promise<void> {
    const db = await getDB();
    const tx = db.transaction(['conversations', 'messages'], 'readwrite');
    await tx.objectStore('conversations').delete(id);
    const index = tx.objectStore('messages').index('conversationId');
    let cursor = await index.openCursor(id);
    while (cursor) {
      await cursor.delete();
      cursor = await cursor.continue();
    }
    await tx.done;
  },

  async updateTitle(id: string, title: string): Promise<void> {
    const db = await getDB();
    const row = await db.get('conversations', id);
    if (row) {
      row.title = title;
      row.updatedAt = Date.now();
      await db.put('conversations', row);
    }
  },

  async appendMessage(conversationId: string, msg: ChatMessage): Promise<void> {
    const db = await getDB();
    const row: MessageRow = {
      id: msg.id,
      conversationId,
      role: msg.role,
      content: msg.content,
      createdAt: msg.createdAt,
      toolName: msg.toolName,
      toolArgs: msg.toolArgs,
      toolResult: msg.toolResult,
    };
    await db.put('messages', row);
    const conv = await db.get('conversations', conversationId);
    if (conv) {
      conv.updatedAt = Date.now();
      await db.put('conversations', conv);
    }
  },

  async getMessages(conversationId: string): Promise<ChatMessage[]> {
    const db = await getDB();
    const index = db.transaction('messages').store.index('conversationId');
    const rows = await index.getAll(conversationId);
    return rows.sort((a, b) => a.createdAt - b.createdAt).map(rowToMessage);
  },
};
