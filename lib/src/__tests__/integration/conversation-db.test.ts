import { describe, it, expect, beforeEach } from 'vitest';
import 'fake-indexeddb/auto';
import { conversationDb } from '../../services/conversation-db';

async function clearAllData(): Promise<void> {
  const convs = await conversationDb.getAllConversations();
  for (const conv of convs) {
    await conversationDb.deleteConversation(conv.id);
  }
}

describe('conversationDb', () => {
  beforeEach(async () => {
    await clearAllData();
  });

  describe('createConversation', () => {
    it('creates a conversation with default title', async () => {
      const conv = await conversationDb.createConversation();
      expect(conv.id).toMatch(/^conv_\d+$/);
      expect(conv.title).toBe('새 대화');
      expect(conv.createdAt).toBeGreaterThan(0);
    });

    it('creates a conversation with custom title', async () => {
      const conv = await conversationDb.createConversation('My Chat');
      expect(conv.title).toBe('My Chat');
    });
  });

  describe('getAllConversations', () => {
    it('returns empty array after clearing', async () => {
      const convs = await conversationDb.getAllConversations();
      expect(convs).toEqual([]);
    });

    it('returns conversations sorted by updatedAt desc', async () => {
      const c1 = await conversationDb.createConversation('First');
      await new Promise((r) => setTimeout(r, 10));
      const c2 = await conversationDb.createConversation('Second');
      const convs = await conversationDb.getAllConversations();
      expect(convs).toHaveLength(2);
      expect(convs[0].id).toBe(c2.id);
      expect(convs[1].id).toBe(c1.id);
    });
  });

  describe('deleteConversation', () => {
    it('deletes a conversation', async () => {
      const conv = await conversationDb.createConversation();
      await conversationDb.deleteConversation(conv.id);
      const convs = await conversationDb.getAllConversations();
      expect(convs).toHaveLength(0);
    });

    it('deletes associated messages', async () => {
      const conv = await conversationDb.createConversation();
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_1',
        role: 'user',
        content: 'hello',
        createdAt: Date.now(),
      });
      await conversationDb.deleteConversation(conv.id);
      const msgs = await conversationDb.getMessages(conv.id);
      expect(msgs).toHaveLength(0);
    });

    it('does not throw for non-existent id', async () => {
      await expect(conversationDb.deleteConversation('nonexistent')).resolves.not.toThrow();
    });
  });

  describe('updateTitle', () => {
    it('updates conversation title', async () => {
      const conv = await conversationDb.createConversation('Old Title');
      await conversationDb.updateTitle(conv.id, 'New Title');
      const convs = await conversationDb.getAllConversations();
      expect(convs[0].title).toBe('New Title');
    });

    it('does not throw for non-existent id', async () => {
      await expect(conversationDb.updateTitle('nonexistent', 'title')).resolves.not.toThrow();
    });
  });

  describe('appendMessage', () => {
    it('appends a message to conversation', async () => {
      const conv = await conversationDb.createConversation();
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_1',
        role: 'user',
        content: 'hello',
        createdAt: Date.now(),
      });
      const msgs = await conversationDb.getMessages(conv.id);
      expect(msgs).toHaveLength(1);
      expect(msgs[0].content).toBe('hello');
    });

    it('appends multiple messages in order', async () => {
      const conv = await conversationDb.createConversation();
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_1',
        role: 'user',
        content: 'first',
        createdAt: 1000,
      });
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_2',
        role: 'assistant',
        content: 'second',
        createdAt: 2000,
      });
      const msgs = await conversationDb.getMessages(conv.id);
      expect(msgs).toHaveLength(2);
      expect(msgs[0].content).toBe('first');
      expect(msgs[1].content).toBe('second');
    });

    it('preserves tool metadata', async () => {
      const conv = await conversationDb.createConversation();
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_tool',
        role: 'assistant',
        content: '',
        createdAt: Date.now(),
        toolName: 'calculator',
        toolArgs: '{"expression":"2+3"}',
        toolResult: '5',
      });
      const msgs = await conversationDb.getMessages(conv.id);
      expect(msgs[0].toolName).toBe('calculator');
      expect(msgs[0].toolArgs).toBe('{"expression":"2+3"}');
      expect(msgs[0].toolResult).toBe('5');
    });

    it('updates conversation updatedAt', async () => {
      const conv = await conversationDb.createConversation();
      const beforeUpdatedAt = conv.updatedAt;
      await new Promise((r) => setTimeout(r, 10));
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_1',
        role: 'user',
        content: 'hello',
        createdAt: Date.now(),
      });
      const convs = await conversationDb.getAllConversations();
      expect(convs[0].updatedAt).toBeGreaterThanOrEqual(beforeUpdatedAt);
    });
  });

  describe('getMessages', () => {
    it('returns empty array for non-existent conversation', async () => {
      const msgs = await conversationDb.getMessages('nonexistent');
      expect(msgs).toEqual([]);
    });

    it('returns messages sorted by createdAt asc', async () => {
      const conv = await conversationDb.createConversation();
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_2',
        role: 'assistant',
        content: 'second',
        createdAt: 2000,
      });
      await conversationDb.appendMessage(conv.id, {
        id: 'msg_1',
        role: 'user',
        content: 'first',
        createdAt: 1000,
      });
      const msgs = await conversationDb.getMessages(conv.id);
      expect(msgs[0].content).toBe('first');
      expect(msgs[1].content).toBe('second');
    });

    it('separates messages by conversation', async () => {
      const conv1 = await conversationDb.createConversation();
      const conv2 = await conversationDb.createConversation();
      const id1 = `msg_${conv1.id}_1`;
      const id2 = `msg_${conv2.id}_2`;
      await conversationDb.appendMessage(conv1.id, {
        id: id1,
        role: 'user',
        content: 'conv1 msg',
        createdAt: 1000,
      });
      await conversationDb.appendMessage(conv2.id, {
        id: id2,
        role: 'user',
        content: 'conv2 msg',
        createdAt: 2000,
      });
      const allMessages = await conversationDb.getMessages(conv1.id);
      const conv1Msgs = allMessages.filter((m) => m.content === 'conv1 msg');
      expect(conv1Msgs).toHaveLength(1);
      const conv2Msgs = await conversationDb.getMessages(conv2.id);
      const conv2Filtered = conv2Msgs.filter((m) => m.content === 'conv2 msg');
      expect(conv2Filtered).toHaveLength(1);
    });
  });
});
