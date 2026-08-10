const assert = require('assert');
const { checkEmergencyStatus } = require('../scripts/check-emergency-status');

// Mock Firestore references
class MockDocRef {
  constructor(id, data, collections = {}) {
    this.id = id;
    this._data = data;
    this._collections = collections;
    this._updates = [];
    this.ref = this; // Self-reference for doc.ref
  }
  async get() { return { exists: !!this._data, data: () => this._data }; }
  data() { return this._data; }
  async set(data, options) { this._updates.push({ data, options }); }
  async update(data) { this._updates.push({ data }); }
  collection(name) { return this._collections[name] || new MockCollection([]); }
}

class MockCollection {
  constructor(docs) {
    this._docs = docs;
  }
  async get() { return { empty: this._docs.length === 0, size: this._docs.length, docs: this._docs }; }
  doc(id) { return this._docs.find(d => d.id === id) || new MockDocRef(id, null); }
}

// Mock Firestore DB
class MockFirestore {
  constructor(users) {
    this.users = users;
  }
  collection(name) {
    if (name === 'users') {
      return new MockCollection(this.users);
    }
    return new MockCollection([]);
  }
}

// Global fetch mock
let fetchCallCount = 0;
let fetchShouldFail = false;
async function mockFetch(url, options) {
  fetchCallCount++;
  if (fetchShouldFail) {
    return { ok: false, status: 500, text: async () => 'Internal Server Error' };
  }
  return { ok: true, status: 200, text: async () => 'OK' };
}

async function runTests() {
  console.log('--- Running checkEmergencyStatus tests ---\n');

  // Test cases setup
  const nowMs = Date.now();
  const futureMs = nowMs + 100000;
  const pastMs = nowMs - 100000;

  // 1. Disabled switch -> no email
  const userDisabled = new MockDocRef('user1', { name: 'U1' }, {
    publicMeta: new MockCollection([
      new MockDocRef('info', { emergencyEnabled: false, emergencyDeadline: { seconds: pastMs / 1000 } })
    ]),
    nominees: new MockCollection([new MockDocRef('nom1', { email: 'nom1@test.com' })])
  });

  // 2. Missing deadline -> no email
  const userMissingDl = new MockDocRef('user2', { name: 'U2' }, {
    publicMeta: new MockCollection([
      new MockDocRef('info', { emergencyEnabled: true })
    ]),
    nominees: new MockCollection([new MockDocRef('nom2', { email: 'nom2@test.com' })])
  });

  // 3. Before deadline -> no email
  const userFuture = new MockDocRef('user3', { name: 'U3' }, {
    publicMeta: new MockCollection([
      new MockDocRef('info', { emergencyEnabled: true, emergencyDeadline: { seconds: futureMs / 1000 } })
    ]),
    nominees: new MockCollection([new MockDocRef('nom3', { email: 'nom3@test.com' })])
  });

  // 4. Exactly/after deadline -> email attempted
  const nom4 = new MockDocRef('nom4', { email: 'nom4@test.com' });
  const userInfo4 = new MockDocRef('info', { emergencyEnabled: true, emergencyDeadline: { seconds: pastMs / 1000 } });
  const userExpired = new MockDocRef('user4', { name: 'U4' }, {
    publicMeta: new MockCollection([userInfo4]),
    nominees: new MockCollection([nom4])
  });

  // 7. Successfully notified nominee for same deadline -> skipped
  const nom7 = new MockDocRef('nom7', { email: 'nom7@test.com', notifiedDeadlines: { [pastMs]: true } });
  const userAlreadyNotified = new MockDocRef('user7', { name: 'U7' }, {
    publicMeta: new MockCollection([
      new MockDocRef('info', { emergencyEnabled: true, emergencyDeadline: { seconds: pastMs / 1000 } })
    ]),
    nominees: new MockCollection([nom7])
  });

  const db = new MockFirestore([
    userDisabled,
    userMissingDl,
    userFuture,
    userExpired,
    userAlreadyNotified
  ]);

  fetchCallCount = 0;
  fetchShouldFail = false;

  await checkEmergencyStatus(db, mockFetch);

  // Assertions
  assert.strictEqual(fetchCallCount, 1, 'Should only send exactly 1 email (for user4)');
  assert.strictEqual(userInfo4._updates.length, 1, 'Should update emergencyStatus for user4');
  assert.strictEqual(userInfo4._updates[0].data.emergencyStatus, 'expired', 'Should set status to expired');
  assert.strictEqual(nom4._updates.length, 1, 'Should record success on nom4');
  assert.strictEqual(nom4._updates[0].data.notifiedDeadlines[pastMs], true, 'Success marker correct');
  assert.strictEqual(nom7._updates.length, 0, 'Should skip nom7 completely');

  console.log('✅ Basic tests passed!');

  // Test Email Failure & Multiple Nominees
  console.log('\n--- Testing Email Failure & Multiple Nominees ---');
  fetchCallCount = 0;
  let customFetchCallCount = 0;
  
  const nomA = new MockDocRef('nomA', { email: 'nomA@test.com' });
  const nomB = new MockDocRef('nomB', { email: 'nomB@test.com' }); // Will fail
  const nomC = new MockDocRef('nomC', { email: 'nomC@test.com' });

  const failingDb = new MockFirestore([
    new MockDocRef('userFail', { name: 'Fail' }, {
      publicMeta: new MockCollection([
        new MockDocRef('info', { emergencyEnabled: true, emergencyDeadline: { seconds: pastMs / 1000 } })
      ]),
      nominees: new MockCollection([nomA, nomB, nomC])
    })
  ]);

  const customFetchMock = async (url, options) => {
    customFetchCallCount++;
    const payload = JSON.parse(options.body);
    if (payload.template_params.email === 'nomB@test.com') {
      return { ok: false, status: 500, text: async () => 'Error' };
    }
    return { ok: true, status: 200, text: async () => 'OK' };
  };

  try {
    await checkEmergencyStatus(failingDb, customFetchMock);
    assert.fail('Should have thrown an error due to partial failure');
  } catch (err) {
    assert.strictEqual(err.message, 'One or more emails failed to send.', 'Expected partial failure throw');
  }

  assert.strictEqual(customFetchCallCount, 3, 'Should attempt to email all 3 nominees despite failure in middle');
  assert.strictEqual(nomA._updates.length, 1, 'nomA should get success marker');
  assert.strictEqual(nomB._updates.length, 0, 'nomB should NOT get success marker');
  assert.strictEqual(nomC._updates.length, 1, 'nomC should get success marker');

  // --- TEST: SKIP MIGRATED AND DEDUPLICATE ---
  let fetchCountDedupe = 0;
  const nomMigrated = new MockDocRef('random123', { email: 'dup@test.com', migratedToCanonical: true });
  const nomDup1 = new MockDocRef('dup1', { email: 'dup@test.com' });
  const nomDup2 = new MockDocRef('dup2', { email: 'DUP@test.com ' }); // spaces and caps
  
  const dedupeDb = new MockFirestore([
    new MockDocRef('userDedupe', { name: 'Dedupe' }, {
      publicMeta: new MockCollection([
        new MockDocRef('info', { emergencyEnabled: true, emergencyDeadline: { seconds: pastMs / 1000 } })
      ]),
      nominees: new MockCollection([nomMigrated, nomDup1, nomDup2])
    })
  ]);

  const fetchDedupeMock = async () => {
    fetchCountDedupe++;
    return { ok: true, status: 200, text: async () => 'OK' };
  };

  await checkEmergencyStatus(dedupeDb, fetchDedupeMock);
  
  assert.strictEqual(fetchCountDedupe, 1, 'Should only send exactly one email after deduplication and skipping migrated');

  console.log('✅ Deduplication tests passed!');

  console.log('\n🎉 ALL MOCK TESTS PASSED SUCCESSFULLY!');
}

runTests().catch(err => {
  console.error('Test Failed:', err);
  process.exit(1);
});
