import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, increment, query, setDoc, updateDoc, where,
  writeBatch,
} from 'firebase/firestore';

// Tutor directory (tutor_profiles) and ratings (reviews). Separate project id
// so this file can run in parallel with the others.
let env;

before(async () => {
  const hostPort = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:4650').split(':');
  env = await initializeTestEnvironment({
    projectId: 'siyaq-rules-test-directory',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: hostPort[0],
      port: Number(hostPort[1]),
    },
  });
});
after(() => env.cleanup());

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const APP = {
  phone: '+20 100 123 4567',
  qualification: 'بكالوريوس تربية',
  experienceYears: 5,
  subjects: ['الرياضيات', 'العلوم'],
  stages: ['prep', 'secondary'],
  bio: 'معلم رياضيات بخبرة خمس سنوات في الشرح المبسط.',
  availability: 'مساءً',
  status: 'approved',
  submittedAt: '2030-03-01T10:00:00.000',
};

const profileFor = (name, over = {}) => ({
  name,
  subjects: APP.subjects,
  stages: APP.stages,
  qualification: APP.qualification,
  experienceYears: APP.experienceYears,
  bio: APP.bio,
  active: true,
  ratingSum: 0,
  ratingCount: 0,
  completedSessions: 0,
  cancelledSessions: 0,
  lastSessionId: '',
  lastReviewId: '',
  ...over,
});

const SESSION = {
  subject: 'الرياضيات',
  scheduledAt: '2030-01-01T10:00:00.000',
  isTrial: true,
  googleMeetLink: null,
};

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const u = (id, data) => setDoc(doc(f, 'users', id), data);
    await u('admin1', { name: 'Admin', email: 'a@x.com', role: 'admin' });
    await u('tutorA', { name: 'Tutor A', email: 'ta@x.com', role: 'tutor', approved: true });
    await u('tutorN', { name: 'Tutor N', email: 'tn@x.com', role: 'tutor', approved: true });
    await u('tutorS', { name: 'Tutor S', email: 'ts@x.com', role: 'tutor', approved: false });
    await u('tutorP', { name: 'Tutor P', email: 'tp@x.com', role: 'tutor', approved: false });
    await u('stu1', { name: 'Student 1', email: 's1@x.com', role: 'student' });
    await u('stu2', { name: 'Student 2', email: 's2@x.com', role: 'student' });
    await u('par1', { name: 'Parent 1', email: 'p1@x.com', role: 'parent', childIds: ['stu1'] });

    const app = (id, over = {}) => setDoc(doc(f, 'tutor_applications', id), { ...APP, ...over });
    await app('tutorA');
    await app('tutorN'); // approved, not yet in the directory
    await app('tutorS'); // suspended
    await app('tutorP', { status: 'submitted' }); // waiting for review

    await setDoc(doc(f, 'tutor_profiles', 'tutorA'), profileFor('Tutor A'));
    await setDoc(doc(f, 'tutor_profiles', 'tutorS'), profileFor('Tutor S', { active: false }));

    const s = (id, data) => setDoc(doc(f, 'sessions', id), { ...SESSION, ...data });
    await s('confA', { studentId: 'stu1', tutorId: 'tutorA', status: 'confirmed' });
    await s('confA2', { studentId: 'stu1', tutorId: 'tutorA', status: 'confirmed' });
    await s('doneA', { studentId: 'stu1', tutorId: 'tutorA', status: 'completed' });
    await s('doneA2', { studentId: 'stu1', tutorId: 'tutorA', status: 'completed' });
    await s('doneS', { studentId: 'stu1', tutorId: 'tutorS', status: 'completed' });
    await s('doneN', { studentId: 'stu2', tutorId: 'tutorN', status: 'completed' });
    await s('confN', { studentId: 'stu2', tutorId: 'tutorN', status: 'confirmed' });
  });
});

const profileRef = (as, id) => doc(db(as), 'tutor_profiles', id);

/** What the app does when a tutor finishes a session. */
const finish = (as, sessionId, status) => {
  const f = db(as);
  const b = writeBatch(f);
  b.update(doc(f, 'sessions', sessionId), { status });
  b.update(doc(f, 'tutor_profiles', as), {
    [status === 'completed' ? 'completedSessions' : 'cancelledSessions']: increment(1),
    lastSessionId: sessionId,
  });
  return b.commit();
};

/** What the app does when a student rates a session. */
const rate = (as, sessionId, tutorId, rating, { bump = rating, studentId = as } = {}) => {
  const f = db(as);
  const b = writeBatch(f);
  b.set(doc(f, 'reviews', sessionId), {
    studentId, tutorId, rating, createdAt: '2030-01-02T10:00:00.000',
  });
  b.update(doc(f, 'tutor_profiles', tutorId), {
    ratingSum: increment(bump),
    ratingCount: increment(1),
    lastReviewId: sessionId,
  });
  return b.commit();
};

describe('directory: reads', () => {
  it('any signed-in user can list active tutors', async () => {
    const q = query(collection(db('stu1'), 'tutor_profiles'), where('active', '==', true));
    const snap = await assertSucceeds(getDocs(q));
    assert(snap.docs.map((d) => d.id).join() === 'tutorA');
    await assertSucceeds(getDocs(query(collection(db('par1'), 'tutor_profiles'),
      where('active', '==', true))));
  });
  it('an unfiltered list is refused except for admins', async () => {
    await assertFails(getDocs(collection(db('stu1'), 'tutor_profiles')));
    await assertSucceeds(getDocs(collection(db('admin1'), 'tutor_profiles')));
  });
  it('anonymous users cannot read the directory', async () => {
    await assertFails(getDocs(query(collection(anon(), 'tutor_profiles'),
      where('active', '==', true))));
    await assertFails(getDoc(doc(anon(), 'tutor_profiles', 'tutorA')));
  });
  it('a single profile can be read even when inactive', async () => {
    await assertSucceeds(getDoc(profileRef('stu1', 'tutorS')));
  });
});

describe('directory: admin', () => {
  it('lists an approved tutor from their application', async () => {
    await assertSucceeds(setDoc(profileRef('admin1', 'tutorN'),
      profileFor('Tutor N', { completedSessions: 1 })));
  });
  it('approving and listing in one batch works', async () => {
    const f = db('admin1');
    const b = writeBatch(f);
    b.update(doc(f, 'tutor_applications', 'tutorP'), {
      status: 'approved', reviewedAt: '2030-03-02T10:00:00.000',
    });
    b.update(doc(f, 'users', 'tutorP'), { approved: true });
    b.set(doc(f, 'tutor_profiles', 'tutorP'), profileFor('Tutor P'));
    await assertSucceeds(b.commit());
  });
  it('cannot list a tutor who is not approved', async () => {
    await assertFails(setDoc(profileRef('admin1', 'tutorP'), profileFor('Tutor P')));
  });
  it('cannot list content that differs from the application or profile', async () => {
    await assertFails(setDoc(profileRef('admin1', 'tutorN'), profileFor('Someone else')));
    await assertFails(setDoc(profileRef('admin1', 'tutorN'),
      profileFor('Tutor N', { subjects: ['القرآن الكريم'] })));
    await assertFails(setDoc(profileRef('admin1', 'tutorN'),
      profileFor('Tutor N', { experienceYears: 30 })));
  });
  it('cannot seed fake ratings or extra fields', async () => {
    await assertFails(setDoc(profileRef('admin1', 'tutorN'),
      profileFor('Tutor N', { ratingSum: 50, ratingCount: 10 })));
    await assertFails(setDoc(profileRef('admin1', 'tutorN'),
      profileFor('Tutor N', { featured: true })));
    await assertFails(setDoc(profileRef('admin1', 'tutorN'),
      profileFor('Tutor N', { completedSessions: -1 })));
  });
  it('only an admin can create a profile', async () => {
    await assertFails(setDoc(profileRef('tutorN', 'tutorN'), profileFor('Tutor N')));
    await assertFails(setDoc(profileRef('stu1', 'tutorN'), profileFor('Tutor N')));
  });
  it('can hide or show a tutor, and nothing else', async () => {
    await assertSucceeds(updateDoc(profileRef('admin1', 'tutorA'), { active: false }));
    await assertSucceeds(updateDoc(profileRef('admin1', 'tutorS'), { active: true }));
    await assertFails(updateDoc(profileRef('admin1', 'tutorA'), { ratingSum: 100 }));
    await assertFails(updateDoc(profileRef('tutorA', 'tutorA'), { active: false }));
  });
  it('profiles cannot be deleted', async () => {
    await assertFails(deleteDoc(profileRef('admin1', 'tutorA')));
  });
});

describe('directory: session counters', () => {
  it('a tutor completing or cancelling bumps their own counter', async () => {
    await assertSucceeds(finish('tutorA', 'confA', 'completed'));
    await assertSucceeds(finish('tutorA', 'confA2', 'cancelled'));
    const p = (await getDoc(profileRef('stu1', 'tutorA'))).data();
    assert(p.completedSessions === 1 && p.cancelledSessions === 1);
  });
  it('finishing a session without counting it is refused once listed', async () => {
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { status: 'completed' }));
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { status: 'cancelled' }));
  });
  it('a tutor who is not listed yet can still finish sessions', async () => {
    await assertSucceeds(updateDoc(doc(db('tutorN'), 'sessions', 'confN'), { status: 'completed' }));
  });
  it('the counter cannot move without the session changing', async () => {
    await assertFails(updateDoc(profileRef('tutorA', 'tutorA'),
      { completedSessions: increment(1), lastSessionId: 'confA' }));
    await assertFails(updateDoc(profileRef('tutorA', 'tutorA'),
      { completedSessions: increment(1), lastSessionId: 'doneA' }));
  });
  it('the counter must match the new status and move by exactly one', async () => {
    const f = db('tutorA');
    const wrongField = writeBatch(f);
    wrongField.update(doc(f, 'sessions', 'confA'), { status: 'cancelled' });
    wrongField.update(doc(f, 'tutor_profiles', 'tutorA'),
      { completedSessions: increment(1), lastSessionId: 'confA' });
    await assertFails(wrongField.commit());

    const byTwo = writeBatch(f);
    byTwo.update(doc(f, 'sessions', 'confA'), { status: 'completed' });
    byTwo.update(doc(f, 'tutor_profiles', 'tutorA'),
      { completedSessions: increment(2), lastSessionId: 'confA' });
    await assertFails(byTwo.commit());
  });
  it("a tutor cannot touch someone else's counters or their ratings", async () => {
    await assertFails(updateDoc(profileRef('tutorN', 'tutorA'),
      { cancelledSessions: increment(1), lastSessionId: 'confA' }));
    await assertFails(updateDoc(profileRef('tutorA', 'tutorA'), { ratingSum: increment(5) }));
  });
});

describe('reviews', () => {
  it('a student rates their completed session and the tutor average moves', async () => {
    await assertSucceeds(rate('stu1', 'doneA', 'tutorA', 5));
    await assertSucceeds(rate('stu1', 'doneA2', 'tutorA', 3));
    const p = (await getDoc(profileRef('stu1', 'tutorA'))).data();
    assert(p.ratingSum === 8 && p.ratingCount === 2);
  });
  it('each session can be rated only once', async () => {
    await assertSucceeds(rate('stu1', 'doneA', 'tutorA', 5));
    await assertFails(rate('stu1', 'doneA', 'tutorA', 1));
  });
  it('a suspended tutor still gets the rating counted', async () => {
    await assertSucceeds(rate('stu1', 'doneS', 'tutorS', 4));
  });
  it('the bump must equal the rating', async () => {
    await assertFails(rate('stu1', 'doneA', 'tutorA', 1, { bump: 5 }));
  });
  it('a review without the profile bump is refused once listed', async () => {
    await assertFails(setDoc(doc(db('stu1'), 'reviews', 'doneA'), {
      studentId: 'stu1', tutorId: 'tutorA', rating: 5, createdAt: '2030-01-02T10:00:00.000',
    }));
  });
  it('ratings cannot be bumped without a new review', async () => {
    await assertFails(updateDoc(profileRef('stu1', 'tutorA'),
      { ratingSum: increment(5), ratingCount: increment(1), lastReviewId: 'doneA' }));
  });
  it("only that session's student can rate, only once it's completed", async () => {
    await assertFails(rate('stu2', 'doneA', 'tutorA', 5));
    await assertFails(rate('stu2', 'doneA', 'tutorA', 5, { studentId: 'stu1' }));
    await assertFails(rate('stu1', 'confA', 'tutorA', 5));
    await assertFails(rate('tutorA', 'doneA', 'tutorA', 5, { studentId: 'stu1' }));
    await assertFails(rate('par1', 'doneA', 'tutorA', 5, { studentId: 'stu1' }));
  });
  it('the review must name the real tutor and a 1–5 integer', async () => {
    await assertFails(rate('stu1', 'doneA', 'tutorS', 5));
    await assertFails(rate('stu1', 'doneA', 'tutorA', 6));
    await assertFails(rate('stu1', 'doneA', 'tutorA', 0));
    await assertFails(rate('stu1', 'doneA', 'tutorA', 4.5));
  });
  it('reviews are readable by their student, the tutor and admins only', async () => {
    await rate('stu1', 'doneA', 'tutorA', 5);
    await assertSucceeds(getDocs(query(collection(db('stu1'), 'reviews'),
      where('studentId', '==', 'stu1'))));
    await assertSucceeds(getDoc(doc(db('tutorA'), 'reviews', 'doneA')));
    await assertSucceeds(getDoc(doc(db('admin1'), 'reviews', 'doneA')));
    await assertFails(getDoc(doc(db('stu2'), 'reviews', 'doneA')));
    await assertFails(getDoc(doc(db('tutorN'), 'reviews', 'doneA')));
  });
  it('reviews cannot be edited or deleted', async () => {
    await rate('stu1', 'doneA', 'tutorA', 5);
    await assertFails(updateDoc(doc(db('stu1'), 'reviews', 'doneA'), { rating: 1 }));
    await assertFails(deleteDoc(doc(db('stu1'), 'reviews', 'doneA')));
  });
});

function assert(ok) {
  if (!ok) throw new Error('assertion failed');
}
