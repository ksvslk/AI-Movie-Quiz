// functions/src/index.ts

import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { getMessaging, Message } from 'firebase-admin/messaging';
import {
    getRemoteConfig,
    RemoteConfigTemplate,
} from 'firebase-admin/remote-config';

admin.initializeApp();

/**
 * A robust helper function to safely extract a string value from a Remote Config
 * parameter, working around potential SDK type definition issues.
 * @param {RemoteConfigTemplate} template The Remote Config template object.
 * @param {string} key The name of the parameter to fetch.
 * @param {string} fallback A fallback string to use if the parameter is not found.
 * @return {string} The parameter's value or the fallback string.
 */
function getParameterValueAsString(
    template: RemoteConfigTemplate,
    key: string,
    fallback: string,
): string {
    const parameter = template.parameters[key];

    if (!parameter?.defaultValue) {
        return fallback;
    }

    // Use `as any` to bypass a potential type definition mismatch in the SDK.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const value = (parameter.defaultValue as any).value;

    if (typeof value === 'string') {
        return value;
    }

    return fallback;
}

export const sendNewLevelNotification = onDocumentCreated(
    'levels/{levelId}',
    async (event) => {
        const snapshot = event.data;
        if (!snapshot) {
            console.log('No data associated with the event, skipping.');
            return;
        }

        const newLevel = snapshot.data();
        const levelCharacteristic: string =
            newLevel.characteristic ?? 'A New Challenge';
        const levelNumber: number = newLevel.levelNumber ?? 0;

        // --- Remote Config Logic ---
        const remoteConfig = getRemoteConfig();
        const template = await remoteConfig.getTemplate();

        const notificationTitle = getParameterValueAsString(
            template,
            'NEW_LEVEL_NOTIFICATION_TITLE',
            'New Level Available!',
        );

        const bodyTemplate = getParameterValueAsString(
            template,
            'NEW_LEVEL_NOTIFICATION_BODY',
            'Level {levelNumber}: {levelTitle} is now ready to play!',
        );

        const notificationBody = bodyTemplate
            .replace('{levelNumber}', String(levelNumber))
            .replace('{levelTitle}', levelCharacteristic);

        console.log(`Sending notification: "${notificationTitle}" - "${notificationBody}"`);

        // --- FCM Logic ---
        const message: Message = {
            notification: {
                title: notificationTitle,
                body: notificationBody,
            },
            data: {
                levelNumber: String(levelNumber),
            },
            topic: 'new_levels',
        };

        try {
            const messaging = getMessaging();
            const response = await messaging.send(message);
            console.log('Successfully sent message:', response);
        } catch (error) {
            console.error('Error sending message:', error);
        }
    },
);