import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc, writeBatch,
} from 'firebase/firestore';

// Separate project id so this file can run in parallel with rules.test.js.
let env;

before(async () => {
  const hostPort = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:4650').split(':');
  env = await initializeTestEnvironment({
    projectId: 'siyaq-rules-test-applications',
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

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const u = (id, data) => setDoc(doc(f, 'users', id), data);
    await u('admin1', { name: 'Admin', email: 'a@x.com', role: 'admin' });
    await u('tutorA', { name: 'Tutor A', email: 'ta@x.com', role: 'tutor', approved: true });
    await u('tutorB', { name: 'Tutor B', email: 'tb@x.com', role: 'tutor', approved: false });
    await u('tutorC', { name: 'Tutor C', email: 'tc@x.com', role: 'tutor', approved: false });
    await u('stu1', { name: 'Student 1', email: 's1@x.com', role: 'student' });
    await u('par1', { name: 'Parent 1', email: 'p1@x.com', role: 'parent', childIds: [] });
  });
});

const application = (over = {}) => ({
  phone: '+20 100 123 4567',
  qualification: 'بكالوريوس تربية - جامعة القاهرة',
  experienceYears: 5,
  subjects: ['الرياضيات', 'العلوم'],
  stages: ['prep', 'secondary'],
  bio: 'معلم رياضيات بخبرة خمس سنوات في الشرح المبسط.',
  availability: 'مساءً بعد الخامسة',
  status: 'submitted',
  submittedAt: '2030-03-01T10:00:00.000',
  ...over,
});

const REVIEWED_AT = '2030-03-02T10:00:00.000';
const ref = (uid, as = uid) => doc(db(as), 'tutor_applications', uid);
const seed = (uid, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'tutor_applications', uid), data));

describe('submitting', () => {
  it('an unapproved tutor can submit their own application', async () => {
    await assertSucceeds(setDoc(ref('tutorB'), application()));
  });

  it('a tutor cannot submit for someone else; non-tutors and anonymous cannot submit', async () => {
    await assertFails(setDoc(ref('tutorC', 'tutorB'), application()));
    await assertFails(setDoc(ref('stu1'), application()));
    await assertFails(setDoc(ref('par1'), application()));
    await assertFails(setDoc(doc(anon(), 'tutor_applications', 'tutorB'), application()));
  });

  it('an already approved tutor cannot submit', async () => {
    await assertFails(setDoc(ref('tutorA'), application()));
  });

  it('rejects invalid content', async () => {
    const bad = [
      { phone: '12' }, { phone: 'call me' }, { qualification: 'x' },
      { experienceYears: 51 }, { experienceYears: -1 }, { experienceYears: 2.5 },
      { subjects: [] }, { subjects: ['الفيزياء'] }, { stages: [] }, { stages: ['university'] },
      { bio: 'قصير' }, { bio: 'x'.repeat(1001) }, { availability: '' },
    ];
    for (const over of bad) {
      await assertFails(setDoc(ref('tutorB'), application(over)));
    }
  });

  it('rejects a pre-approved status, review fields, unknown fields and a missing date', async () => {
    await assertFails(setDoc(ref('tutorB'), application({ status: 'approved' })));
    await assertFails(setDoc(ref('tutorB'), application({ reviewNote: 'ok' })));
    await assertFails(setDoc(ref('tutorB'), application({ featured: true })));
    const noDate = application();
    delete noDate.submittedAt;
    await assertFails(setDoc(ref('tutorB'), noDate));
  });
});

describe('reading', () => {
  it('only the owner and admins can read; only admins can list', async () => {
    await seed('tutorB', application());
    await assertSucceeds(getDoc(ref('tutorB')));
    await assertSucceeds(getDoc(ref('tutorB', 'admin1')));
    await assertFails(getDoc(ref('tutorB', 'tutorC')));
    await assertFails(getDoc(ref('tutorB', 'tutorA')));
    await assertFails(getDoc(ref('tutorB', 'stu1')));
    await assertSucceeds(getDocs(collection(db('admin1'), 'tutor_applications')));
    await assertFails(getDocs(collection(db('tutorB'), 'tutor_applications')));
  });
});

describe('owner edits', () => {
  it('cannot edit while under review, or approve themselves', async () => {
    await seed('tutorB', application());
    await assertFails(updateDoc(ref('tutorB'), { bio: 'نبذة جديدة أطول من عشرين حرفاً.' }));
    await assertFails(updateDoc(ref('tutorB'), { status: 'approved' }));
    await assertFails(setDoc(ref('tutorB'), application({ bio: 'نبذة جديدة أطول من عشرين حرفاً.' })));
  });

  it('can edit and resubmit after a rejection, but not keep the review fields', async () => {
    await seed('tutorB', {
      ...application(), status: 'rejected',
      reviewNote: 'يرجى توضيح المؤهل', reviewedAt: REVIEWED_AT,
    });
    await assertFails(setDoc(ref('tutorB'), application({ reviewNote: 'يرجى توضيح المؤهل' })));
    await assertFails(setDoc(ref('tutorB'), application({ status: 'approved' })));
    await assertSucceeds(setDoc(ref('tutorB'), application({ qualification: 'ماجستير مناهج وطرق تدريس' })));
  });

  it('cannot resubmit an approved application', async () => {
    await seed('tutorB', { ...application(), status: 'approved', reviewedAt: REVIEWED_AT });
    await assertFails(setDoc(ref('tutorB'), application()));
  });
});

describe('admin decisions', () => {
  it('can approve a submitted application', async () => {
    await seed('tutorB', application());
    await assertSucceeds(updateDoc(ref('tutorB', 'admin1'), { status: 'approved', reviewedAt: REVIEWED_AT }));
  });

  it('can reject only with a real reason', async () => {
    await seed('tutorB', application());
    await assertFails(updateDoc(ref('tutorB', 'admin1'), { status: 'rejected', reviewedAt: REVIEWED_AT }));
    await assertFails(updateDoc(ref('tutorB', 'admin1'),
      { status: 'rejected', reviewNote: 'لا', reviewedAt: REVIEWED_AT }));
    await assertSucceeds(updateDoc(ref('tutorB', 'admin1'),
      { status: 'rejected', reviewNote: 'يرجى إضافة شهادة المؤهل', reviewedAt: REVIEWED_AT }));
  });

  it('cannot re-decide, edit content, or set an invalid status', async () => {
    await seed('tutorB', { ...application(), status: 'approved', reviewedAt: REVIEWED_AT });
    await assertFails(updateDoc(ref('tutorB', 'admin1'),
      { status: 'rejected', reviewNote: 'تغيير القرار', reviewedAt: '2030-03-03T10:00:00.000' }));

    await seed('tutorC', application());
    await assertFails(updateDoc(ref('tutorC', 'admin1'), { bio: 'نص جديد أطول من عشرين حرفاً هنا.' }));
    await assertFails(updateDoc(ref('tutorC', 'admin1'), { status: 'submitted', reviewedAt: REVIEWED_AT }));
  });

  it('other roles cannot decide an application; nothing can be deleted', async () => {
    await seed('tutorB', application());
    await assertFails(updateDoc(ref('tutorB', 'tutorA'), { status: 'approved', reviewedAt: REVIEWED_AT }));
    await assertFails(updateDoc(ref('tutorB', 'stu1'), { status: 'approved', reviewedAt: REVIEWED_AT }));
    await assertFails(deleteDoc(ref('tutorB')));
    await assertFails(deleteDoc(ref('tutorB', 'admin1')));
  });

  it('approval works as one atomic batch with the tutor profile', async () => {
    await seed('tutorB', application());
    const f = db('admin1');
    const batch = writeBatch(f);
    batch.update(doc(f, 'tutor_applications', 'tutorB'), { status: 'approved', reviewedAt: REVIEWED_AT });
    batch.update(doc(f, 'users', 'tutorB'), { approved: true });
    await assertSucceeds(batch.commit());

    await env.withSecurityRulesDisabled(async (ctx) => {
      const profile = await getDoc(doc(ctx.firestore(), 'users', 'tutorB'));
      if (profile.data().approved !== true) throw new Error('profile was not approved');
    });
  });
});
