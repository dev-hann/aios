import { describe, it, expect } from 'vitest';
import { RiskClassifier } from '../../../agent/risk-classifier';

describe('RiskClassifier', () => {
  const classifier = new RiskClassifier();

  describe('safe tools', () => {
    const safeTools = ['calculator', 'timer', 'device_info', 'notepad', 'screen_reader', 'screen_find', 'notification_reader', 'contact_search'];

    for (const tool of safeTools) {
      it(`classifies ${tool} as safe`, () => {
        expect(classifier.classify(tool, '{}')).toBe('safe');
      });
    }

    it('classifies safe tools regardless of args', () => {
      expect(classifier.classify('calculator', '{"expression": "2+3"}')).toBe('safe');
      expect(classifier.classify('notepad', '{"action": "save"}')).toBe('safe');
    });
  });

  describe('app_launcher', () => {
    it('classifies open_settings as low', () => {
      expect(classifier.classify('app_launcher', '{"action": "open_settings"}')).toBe('low');
    });

    it('classifies list_apps as low', () => {
      expect(classifier.classify('app_launcher', '{"action": "list_apps"}')).toBe('low');
    });

    it('classifies open_app as high', () => {
      expect(classifier.classify('app_launcher', '{"action": "open_app"}')).toBe('high');
    });

    it('classifies open_url as high', () => {
      expect(classifier.classify('app_launcher', '{"action": "open_url"}')).toBe('high');
    });

    it('classifies unknown action as low', () => {
      expect(classifier.classify('app_launcher', '{"action": "search"}')).toBe('low');
    });

    it('classifies empty action as low', () => {
      expect(classifier.classify('app_launcher', '{}')).toBe('low');
    });

    it('is case-insensitive for action', () => {
      expect(classifier.classify('app_launcher', '{"action": "OPEN_APP"}')).toBe('high');
      expect(classifier.classify('app_launcher', '{"action": "Open_Settings"}')).toBe('low');
    });
  });

  describe('screen_action', () => {
    it('classifies global as low', () => {
      expect(classifier.classify('screen_action', '{"action": "global"}')).toBe('low');
    });

    it('classifies type with non-sensitive content as low', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "hello world"}')).toBe('low');
    });

    it('classifies type with password as critical', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "enter password123"}')).toBe('critical');
    });

    it('classifies type with PIN as critical', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "enter pin code"}')).toBe('critical');
    });

    it('classifies type with passcode as critical', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "passcode"}')).toBe('critical');
    });

    it('classifies type with SSN as critical', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "SSN number"}')).toBe('critical');
    });

    it('classifies type with credit card as critical', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "credit card number"}')).toBe('critical');
    });

    it('classifies type with CVV as critical', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "CVV"}')).toBe('critical');
    });

    it('classifies type with OTP as critical', () => {
      expect(classifier.classify('screen_action', '{"action": "type", "content": "OTP code"}')).toBe('critical');
    });

    it('classifies tap as low', () => {
      expect(classifier.classify('screen_action', '{"action": "tap"}')).toBe('low');
    });

    it('classifies scroll as low', () => {
      expect(classifier.classify('screen_action', '{"action": "scroll"}')).toBe('low');
    });
  });

  describe('sms_sender', () => {
    it('classifies send as critical', () => {
      expect(classifier.classify('sms_sender', '{"action": "send"}')).toBe('critical');
    });

    it('classifies read as high', () => {
      expect(classifier.classify('sms_sender', '{"action": "read"}')).toBe('high');
    });

    it('classifies empty action as high', () => {
      expect(classifier.classify('sms_sender', '{}')).toBe('high');
    });
  });

  describe('phone_caller', () => {
    it('classifies call as critical', () => {
      expect(classifier.classify('phone_caller', '{"action": "call"}')).toBe('critical');
    });

    it('classifies dial as high', () => {
      expect(classifier.classify('phone_caller', '{"action": "dial"}')).toBe('high');
    });

    it('classifies empty action as high', () => {
      expect(classifier.classify('phone_caller', '{}')).toBe('high');
    });
  });

  describe('unknown tool', () => {
    it('classifies unknown tool as high', () => {
      expect(classifier.classify('unknown_tool', '{}')).toBe('high');
    });

    it('classifies empty tool name as high', () => {
      expect(classifier.classify('', '{}')).toBe('high');
    });
  });

  describe('edge cases', () => {
    it('handles empty args string', () => {
      expect(classifier.classify('calculator', '')).toBe('safe');
    });

    it('handles invalid JSON', () => {
      expect(() => classifier.classify('calculator', 'not json')).toThrow();
    });

    it('handles case-insensitive action for screen_action', () => {
      expect(classifier.classify('screen_action', '{"action": "Type", "content": "Password"}')).toBe('critical');
    });
  });
});
