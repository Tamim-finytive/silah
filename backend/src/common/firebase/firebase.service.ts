import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { applicationDefault, cert, initializeApp, getApps, App } from 'firebase-admin/app';
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

      const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || 'silah-2036a';
      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      const credential = serviceAccountJson
        ? cert(JSON.parse(serviceAccountJson))
        : applicationDefault();

      this.app = initializeApp({ credential, projectId });
      this.logger.log(`Firebase Admin SDK initialized for project ${projectId}`);
    } catch (error) {
      this.logger.warn(`Firebase Admin SDK could not initialize; push delivery is unavailable: ${error}`);
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
  ): Promise<{ successCount: number; failureCount: number; invalidTokens: string[] }> {
    if (!tokens || tokens.length === 0) {
      this.logger.log('[FCM] No tokens provided to send notification');
      return { successCount: 0, failureCount: 0, invalidTokens: [] };
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
          title,
          body,
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
      const invalidTokens = response.responses.flatMap((result, index) => {
        const code = result.error?.code;
        return code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
            ? [uniqueTokens[index]]
            : [];
      });
      this.logger.log(`[FCM] Notification sent: ${response.successCount} succeeded, ${response.failureCount} failed`);

      return {
        successCount: response.successCount,
        failureCount: response.failureCount,
        invalidTokens,
      };
    } catch (error) {
      this.logger.error(`[FCM] Failed to dispatch multicast notification: ${error}`);
      return { successCount: 0, failureCount: uniqueTokens.length, invalidTokens: [] };
    }
  }
}
