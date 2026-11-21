import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { initializeApp, getApps, App } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private app: App | null = null;

  onModuleInit() {
    try {
      const existingApps = getApps();
      if (existingApps.length > 0) {
        this.app = existingApps[0]!;
        this.logger.log('✓ Firebase Admin already initialized');
        return;
      }

      this.app = initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'silah-2036a',
      });
      this.logger.log('✓ Firebase Admin SDK initialized for project silah-2036a');
    } catch (error) {
      this.logger.warn(`Firebase Admin SDK init note (non-fatal): ${error}`);
    }
  }

  /**
   * Send push notification to multiple FCM device tokens
   */
  async sendPushNotification(
    tokens: string[],
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<{ successCount: number; failureCount: number }> {
    if (!tokens || tokens.length === 0) {
      this.logger.log('[FCM] No tokens provided to send notification');
      return { successCount: 0, failureCount: 0 };
    }

    // Deduplicate tokens
    const uniqueTokens = Array.from(new Set(tokens.filter((t) => typeof t === 'string' && t.trim().length > 0)));
    this.logger.log(`[FCM] Sending push notification "${title}" to ${uniqueTokens.length} device(s)`);

    try {
      const message: MulticastMessage = {
        tokens: uniqueTokens,
        notification: {
          title,
          body,
        },
        data: {
          ...data,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'silah_announcements',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      };

      const response = await getMessaging(this.app ?? undefined).sendEachForMulticast(message);
      this.logger.log(`[FCM] Notification sent: ${response.successCount} succeeded, ${response.failureCount} failed`);

      return {
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
    } catch (error) {
      this.logger.error(`[FCM] Failed to dispatch multicast notification: ${error}`);
      return { successCount: 0, failureCount: uniqueTokens.length };
    }
  }
}
