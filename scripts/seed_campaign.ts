/**
 * Campaign seed script — uploads all 100 levels to Firestore.
 *
 * Usage:
 *   npx ts-node scripts/seed_campaign.ts [--project <projectId>]
 *
 * The script reads assets/campaign/world_N.json and writes to:
 *   campaigns/dot_clash/levels/{levelId}
 *   campaigns/dot_clash/worlds/{worldId}
 *
 * Run with Admin SDK credentials (set GOOGLE_APPLICATION_CREDENTIALS).
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

admin.initializeApp();
const db = admin.firestore();

interface LevelJson {
  id: string;
  worldId: number;
  index: number;
  title: string;
  gridSize: number;
  aiDifficulty: string;
  isBoss: boolean;
  persona?: string;
  bossName?: string;
  objectives: Record<string, unknown>;
  rewards: { coins: number; xp: number };
  disabledCells?: string[];
}

const WORLDS = [
  { id: 1, title: 'Basics', subtitle: 'Back of the notebook', levelCount: 10 },
  { id: 2, title: 'Chain Tactics', subtitle: 'Study hall chains', levelCount: 20 },
  { id: 3, title: 'Trap Masters', subtitle: 'Lunch table traps', levelCount: 25 },
  { id: 4, title: 'Speed Arena', subtitle: 'Beat the bell', levelCount: 25 },
  { id: 5, title: 'Chaos Grid', subtitle: 'Broken grids', levelCount: 20 },
];

async function main() {
  const campaignRef = db.collection('campaigns').doc('dot_clash');

  let totalLevels = 0;
  const batch = db.batch();

  for (const world of WORLDS) {
    const filePath = path.join(
      __dirname,
      `../assets/campaign/world_${world.id}.json`,
    );
    const raw = fs.readFileSync(filePath, 'utf-8');
    const levels: LevelJson[] = JSON.parse(raw);

    // Write world metadata
    const worldRef = campaignRef.collection('worlds').doc(String(world.id));
    batch.set(worldRef, {
      ...world,
      seededAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Write each level
    for (const level of levels) {
      const levelRef = campaignRef.collection('levels').doc(level.id);
      batch.set(levelRef, {
        ...level,
        seededAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      totalLevels++;
    }
  }

  await batch.commit();
  console.log(`✅  Seeded ${totalLevels} levels across ${WORLDS.length} worlds.`);
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
