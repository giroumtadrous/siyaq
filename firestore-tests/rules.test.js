import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc, arrayUnion, collection, deleteDoc, doc, getDoc, getDocs, query,
  setDoc, updateDoc, where,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'siyaq-rules-test',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:4650').split(':')[0],
      port: Number((process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:4650').split(':')[1]),
    },
  });
});
after(() => env.cleanup());

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const SESSION = {
  subject: 'الرياضيات',
  scheduledAt: '2030-01-01T10:00:00.000',
  isTrial: true,
  status: 'pending',
  googleMeetLink: null,
};

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const u = (id, data) => setDoc(doc(f, 'users', id), data);
    await u('admin1', { name: 'Admin', email: 'a@x.com', role: 'admin' });
    await u('tutorA', { name: 'Tutor A', email: 'ta@x.com', role: 'tutor', approved: true });
    await u('tutorC', { name: 'Tutor C', email: 'tc@x.com', role: 'tutor', approved: true });
    await u('tutorB', { name: 'Tutor B', email: 'tb@x.com', role: 'tutor', approved: false });
    await u('stu1', { name: 'Student 1', email: 's1@x.com', role: 'student' });
    await u('stu2', { name: 'Student 2', email: 's2@x.com', role: 'student' });
    await u('par1', { name: 'Parent 1', email: 'p1@x.com', role: 'parent', childIds: ['stu1'] });
    await u('par2', { name: 'Parent 2', email: 'p2@x.com', role: 'parent', childIds: [] });

    const s = (id, data) => setDoc(doc(f, 'sessions', id), { ...SESSION, ...data });
    await s('open', { studentId: 'stu1', tutorId: 'TBD' });
    await s('mineA', { studentId: 'stu1', tutorId: 'tutorA' });
    await s('confA', { studentId: 'stu1', tutorId: 'tutorA', status: 'confirmed' });
    await s('doneA', { studentId: 'stu1', tutorId: 'tutorA', status: 'completed' });
    await s('otherC', { studentId: 'stu2', tutorId: 'tutorC' });

    await setDoc(doc(f, 'progress_reports', 'r1'), {
      studentId: 'stu1', tutorId: 'tutorA', subject: 'الرياضيات',
      score: 80, tutorNotes: 'جيد', date: '2030-01-02T10:00:00.000',
    });
  });
});

describe('users: sign-up', () => {
  const newUser = (role, extra = {}) => ({ name: 'New', email: 'n@x.com', role, ...extra });

  it('allows students, parents and tutors to create their own profile', async () => {
    await assertSucceeds(setDoc(doc(db('n1'), 'users', 'n1'), newUser('student')));
    await assertSucceeds(setDoc(doc(db('n2'), 'users', 'n2'), newUser('parent', { childIds: [] })));
    await assertSucceeds(setDoc(doc(db('n3'), 'users', 'n3'), newUser('tutor', { approved: false })));
  });
  it('blocks creating an admin profile', async () => {
    await assertFails(setDoc(doc(db('n1'), 'users', 'n1'), newUser('admin')));
  });
  it('blocks a tutor creating themselves as approved', async () => {
    await assertFails(setDoc(doc(db('n3'), 'users', 'n3'), newUser('tutor', { approved: true })));
    await assertFails(setDoc(doc(db('n3'), 'users', 'n3'), newUser('tutor')));
  });
  it('blocks a parent pre-filling children, and a student carrying extra flags', async () => {
    await assertFails(setDoc(doc(db('n2'), 'users', 'n2'), newUser('parent', { childIds: ['stu1'] })));
    await assertFails(setDoc(doc(db('n1'), 'users', 'n1'), newUser('student', { approved: true })));
    await assertFails(setDoc(doc(db('n1'), 'users', 'n1'), newUser('student', { isAdmin: true })));
  });
  it("blocks creating someone else's profile and anonymous creation", async () => {
    await assertFails(setDoc(doc(db('n1'), 'users', 'other'), newUser('student')));
    await assertFails(setDoc(doc(anon(), 'users', 'n1'), newUser('student')));
  });
  it('blocks overwriting an existing profile to change role', async () => {
    await assertFails(setDoc(doc(db('stu1'), 'users', 'stu1'), newUser('admin')));
  });
});

describe('users: privilege escalation', () => {
  it('a user cannot change their own role or approval', async () => {
    await assertFails(updateDoc(doc(db('stu1'), 'users', 'stu1'), { role: 'admin' }));
    await assertFails(updateDoc(doc(db('tutorB'), 'users', 'tutorB'), { approved: true }));
  });
  it('a user can rename themselves but not change email', async () => {
    await assertSucceeds(updateDoc(doc(db('stu1'), 'users', 'stu1'), { name: 'New Name' }));
    await assertFails(updateDoc(doc(db('stu1'), 'users', 'stu1'), { email: 'evil@x.com' }));
  });
  it('a student cannot give themselves children', async () => {
    await assertFails(updateDoc(doc(db('stu1'), 'users', 'stu1'), { childIds: ['stu2'] }));
  });
  it('only an admin can approve a tutor, and only that field', async () => {
    await assertSucceeds(updateDoc(doc(db('admin1'), 'users', 'tutorB'), { approved: true }));
    await assertFails(updateDoc(doc(db('admin1'), 'users', 'tutorB'), { role: 'admin' }));
    await assertFails(updateDoc(doc(db('admin1'), 'users', 'stu1'), { approved: true }));
    await assertFails(updateDoc(doc(db('tutorA'), 'users', 'tutorB'), { approved: true }));
  });
  it('profiles cannot be deleted', async () => {
    await assertFails(deleteDoc(doc(db('stu1'), 'users', 'stu1')));
    await assertFails(deleteDoc(doc(db('admin1'), 'users', 'stu1')));
  });
});

describe('users: reads', () => {
  it('anyone signed in can read their own profile; anon cannot', async () => {
    await assertSucceeds(getDoc(doc(db('stu1'), 'users', 'stu1')));
    await assertFails(getDoc(doc(anon(), 'users', 'stu1')));
  });
  it("a student cannot read other users' profiles", async () => {
    await assertFails(getDoc(doc(db('stu1'), 'users', 'stu2')));
    await assertFails(getDoc(doc(db('stu1'), 'users', 'tutorA')));
  });
  it('an approved tutor can read a student but not other tutors or parents', async () => {
    await assertSucceeds(getDoc(doc(db('tutorA'), 'users', 'stu1')));
    await assertFails(getDoc(doc(db('tutorA'), 'users', 'tutorC')));
    await assertFails(getDoc(doc(db('tutorA'), 'users', 'par1')));
  });
  it('an unapproved tutor cannot read students', async () => {
    await assertFails(getDoc(doc(db('tutorB'), 'users', 'stu1')));
  });
  it('a parent can read a student doc but not other roles', async () => {
    await assertSucceeds(getDoc(doc(db('par1'), 'users', 'stu1')));
    await assertFails(getDoc(doc(db('par1'), 'users', 'tutorA')));
    await assertFails(getDoc(doc(db('par1'), 'users', 'par2')));
  });
  it('only an admin can list users; nobody else can enumerate', async () => {
    await assertSucceeds(getDocs(collection(db('admin1'), 'users')));
    await assertFails(getDocs(collection(db('par1'), 'users')));
    await assertFails(getDocs(query(collection(db('par1'), 'users'), where('role', '==', 'student'))));
    await assertFails(getDocs(collection(db('tutorA'), 'users')));
  });
});

describe('parent linking', () => {
  it('a parent can link a real student', async () => {
    await assertSucceeds(updateDoc(doc(db('par2'), 'users', 'par2'), { childIds: arrayUnion('stu2') }));
  });
  it('a parent cannot link a non-student or a nonexistent uid', async () => {
    await assertFails(updateDoc(doc(db('par2'), 'users', 'par2'), { childIds: arrayUnion('tutorA') }));
    await assertFails(updateDoc(doc(db('par2'), 'users', 'par2'), { childIds: arrayUnion('admin1') }));
    await assertFails(updateDoc(doc(db('par2'), 'users', 'par2'), { childIds: arrayUnion('nope') }));
  });
  it('a parent cannot add several children in one write', async () => {
    await assertFails(updateDoc(doc(db('par2'), 'users', 'par2'), { childIds: ['stu1', 'stu2'] }));
  });
  it("a parent cannot edit another parent's children", async () => {
    await assertFails(updateDoc(doc(db('par2'), 'users', 'par1'), { childIds: arrayUnion('stu2') }));
  });
});

describe('sessions: booking', () => {
  const book = (over = {}) => ({ studentId: 'stu1', tutorId: 'TBD', ...SESSION, ...over });

  it('a student can book for themselves', async () => {
    await assertSucceeds(addDoc(collection(db('stu1'), 'sessions'), book()));
  });
  it("a student cannot book for someone else", async () => {
    await assertFails(addDoc(collection(db('stu1'), 'sessions'), book({ studentId: 'stu2' })));
  });
  it('a parent can book for a linked child only', async () => {
    await assertSucceeds(addDoc(collection(db('par1'), 'sessions'), book()));
    await assertFails(addDoc(collection(db('par1'), 'sessions'), book({ studentId: 'stu2' })));
    await assertFails(addDoc(collection(db('par2'), 'sessions'), book()));
  });
  it('tutors cannot create bookings', async () => {
    await assertFails(addDoc(collection(db('tutorA'), 'sessions'), book({ studentId: 'tutorA' })));
  });
  it('a booking cannot pre-assign a tutor, pre-confirm, or add fields', async () => {
    await assertFails(addDoc(collection(db('stu1'), 'sessions'), book({ tutorId: 'tutorA' })));
    await assertFails(addDoc(collection(db('stu1'), 'sessions'), book({ status: 'confirmed' })));
    await assertFails(addDoc(collection(db('stu1'), 'sessions'), book({ price: 0 })));
    await assertFails(addDoc(collection(db('stu1'), 'sessions'), book({ googleMeetLink: 'https://x.com' })));
  });
  it('anonymous users cannot book', async () => {
    await assertFails(addDoc(collection(anon(), 'sessions'), book()));
  });
});

describe('sessions: reads (mirrors the app queries)', () => {
  it('a student sees only their own sessions', async () => {
    await assertSucceeds(getDocs(query(collection(db('stu1'), 'sessions'), where('studentId', '==', 'stu1'))));
    await assertFails(getDocs(query(collection(db('stu1'), 'sessions'), where('studentId', '==', 'stu2'))));
    await assertFails(getDocs(collection(db('stu1'), 'sessions')));
  });
  it('an approved tutor sees their sessions and the open requests', async () => {
    await assertSucceeds(getDocs(query(collection(db('tutorA'), 'sessions'), where('tutorId', '==', 'tutorA'))));
    await assertSucceeds(getDocs(query(collection(db('tutorA'), 'sessions'), where('tutorId', '==', 'TBD'))));
    await assertFails(getDocs(query(collection(db('tutorA'), 'sessions'), where('tutorId', '==', 'tutorC'))));
  });
  it('an unapproved tutor sees nothing', async () => {
    await assertFails(getDocs(query(collection(db('tutorB'), 'sessions'), where('tutorId', '==', 'TBD'))));
  });
  it("a parent sees a linked child's sessions only", async () => {
    await assertSucceeds(getDocs(query(collection(db('par1'), 'sessions'), where('studentId', '==', 'stu1'))));
    await assertFails(getDocs(query(collection(db('par1'), 'sessions'), where('studentId', '==', 'stu2'))));
    await assertFails(getDocs(query(collection(db('par2'), 'sessions'), where('studentId', '==', 'stu1'))));
  });
  it('an admin sees everything', async () => {
    await assertSucceeds(getDocs(collection(db('admin1'), 'sessions')));
  });
});

describe('sessions: tutor actions', () => {
  it('a tutor can accept an open request with a link', async () => {
    await assertSucceeds(updateDoc(doc(db('tutorA'), 'sessions', 'open'), {
      tutorId: 'tutorA', status: 'confirmed', googleMeetLink: 'https://meet.google.com/abc',
    }));
  });
  it('a tutor can accept without a link', async () => {
    await assertSucceeds(updateDoc(doc(db('tutorA'), 'sessions', 'open'), {
      tutorId: 'tutorA', status: 'confirmed', googleMeetLink: null,
    }));
  });
  it('a tutor cannot assign a session to someone else or accept one already taken', async () => {
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'open'), { tutorId: 'tutorC', status: 'confirmed' }));
    await assertFails(updateDoc(doc(db('tutorC'), 'sessions', 'mineA'), { tutorId: 'tutorC', status: 'confirmed' }));
  });
  it('an unapproved tutor cannot accept', async () => {
    await assertFails(updateDoc(doc(db('tutorB'), 'sessions', 'open'), { tutorId: 'tutorB', status: 'confirmed' }));
  });
  it('a tutor can confirm, cancel and complete their own sessions in order', async () => {
    await assertSucceeds(updateDoc(doc(db('tutorA'), 'sessions', 'mineA'), { status: 'confirmed' }));
    await assertSucceeds(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { status: 'completed' }));
    await assertSucceeds(updateDoc(doc(db('tutorA'), 'sessions', 'mineA'), { status: 'cancelled' }));
  });
  it('a tutor cannot skip or reverse statuses', async () => {
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'mineA'), { status: 'completed' }));
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'doneA'), { status: 'confirmed' }));
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'doneA'), { status: 'cancelled' }));
  });
  it("a tutor cannot touch another tutor's session", async () => {
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'otherC'), { status: 'confirmed' }));
  });
  it('a tutor can set an https Meet link but not other schemes or fields', async () => {
    await assertSucceeds(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { googleMeetLink: 'https://meet.google.com/xyz' }));
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { googleMeetLink: 'javascript:alert(1)' }));
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { googleMeetLink: 'http://insecure.com' }));
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { studentId: 'stu2' }));
    await assertFails(updateDoc(doc(db('tutorA'), 'sessions', 'confA'), { subject: 'x' }));
  });
  it('students and parents cannot modify sessions', async () => {
    await assertFails(updateDoc(doc(db('stu1'), 'sessions', 'mineA'), { status: 'cancelled' }));
    await assertFails(updateDoc(doc(db('par1'), 'sessions', 'mineA'), { status: 'cancelled' }));
  });
  it('sessions cannot be deleted', async () => {
    await assertFails(deleteDoc(doc(db('stu1'), 'sessions', 'open')));
    await assertFails(deleteDoc(doc(db('admin1'), 'sessions', 'open')));
  });
});

describe('sessions: admin assignment', () => {
  it('an admin can assign an approved tutor to an open request', async () => {
    await assertSucceeds(updateDoc(doc(db('admin1'), 'sessions', 'open'), { tutorId: 'tutorA', status: 'confirmed' }));
  });
  it('an admin cannot assign an unapproved tutor, a non-tutor, or an already-assigned session', async () => {
    await assertFails(updateDoc(doc(db('admin1'), 'sessions', 'open'), { tutorId: 'tutorB', status: 'confirmed' }));
    await assertFails(updateDoc(doc(db('admin1'), 'sessions', 'open'), { tutorId: 'stu1', status: 'confirmed' }));
    await assertFails(updateDoc(doc(db('admin1'), 'sessions', 'mineA'), { tutorId: 'tutorC', status: 'confirmed' }));
  });
  it('non-admins cannot use the admin path', async () => {
    await assertFails(updateDoc(doc(db('stu1'), 'sessions', 'open'), { tutorId: 'tutorA', status: 'confirmed' }));
  });
});

describe('progress reports', () => {
  const report = (over = {}) => ({
    studentId: 'stu1', tutorId: 'tutorA', subject: 'العربية',
    score: 90, tutorNotes: 'ممتاز', date: '2030-02-01T10:00:00.000', ...over,
  });

  it('an approved tutor can write a report as themselves', async () => {
    await assertSucceeds(addDoc(collection(db('tutorA'), 'progress_reports'), report()));
  });
  it('rejects forged tutorId, bad scores, extra fields and unapproved tutors', async () => {
    await assertFails(addDoc(collection(db('tutorA'), 'progress_reports'), report({ tutorId: 'tutorC' })));
    await assertFails(addDoc(collection(db('tutorA'), 'progress_reports'), report({ score: 101 })));
    await assertFails(addDoc(collection(db('tutorA'), 'progress_reports'), report({ score: -1 })));
    await assertFails(addDoc(collection(db('tutorA'), 'progress_reports'), report({ score: '90' })));
    await assertFails(addDoc(collection(db('tutorA'), 'progress_reports'), report({ extra: 1 })));
    await assertFails(addDoc(collection(db('tutorB'), 'progress_reports'), report({ tutorId: 'tutorB' })));
  });
  it('students, parents and anonymous users cannot write reports', async () => {
    await assertFails(addDoc(collection(db('stu1'), 'progress_reports'), report({ tutorId: 'stu1' })));
    await assertFails(addDoc(collection(db('par1'), 'progress_reports'), report({ tutorId: 'par1' })));
    await assertFails(addDoc(collection(anon(), 'progress_reports'), report()));
  });
  it('reports are write-once', async () => {
    await assertFails(updateDoc(doc(db('tutorA'), 'progress_reports', 'r1'), { score: 100 }));
    await assertFails(deleteDoc(doc(db('tutorA'), 'progress_reports', 'r1')));
    await assertFails(deleteDoc(doc(db('admin1'), 'progress_reports', 'r1')));
  });
  it('a student reads only their reports', async () => {
    await assertSucceeds(getDocs(query(collection(db('stu1'), 'progress_reports'), where('studentId', '==', 'stu1'))));
    await assertFails(getDocs(query(collection(db('stu2'), 'progress_reports'), where('studentId', '==', 'stu1'))));
  });
  it("a parent reads a linked child's reports only", async () => {
    await assertSucceeds(getDocs(query(collection(db('par1'), 'progress_reports'), where('studentId', '==', 'stu1'))));
    await assertFails(getDocs(query(collection(db('par2'), 'progress_reports'), where('studentId', '==', 'stu1'))));
  });
  it('an unrelated tutor cannot read them', async () => {
    await assertFails(getDoc(doc(db('tutorC'), 'progress_reports', 'r1')));
    await assertSucceeds(getDoc(doc(db('tutorA'), 'progress_reports', 'r1')));
  });
});

describe('default deny', () => {
  it('unknown collections are closed to everyone', async () => {
    await assertFails(getDoc(doc(db('admin1'), 'secrets', 'x')));
    await assertFails(setDoc(doc(db('admin1'), 'secrets', 'x'), { a: 1 }));
  });
});
