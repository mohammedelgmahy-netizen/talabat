'use client';

import { useState } from 'react';
import { Badge, Button, Card, ErrorBox, Input, PageHeader, Select, Spinner, Table, Td } from '@/components/ui';
import { fmtDateTime, roleLabel } from '@/lib/format';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { APP_TAG, showId, supabase, tempClient } from '@/lib/supabase';
import { useAuth } from '@/components/auth-provider';

interface UserRow {
  id: string;
  role: string;
  full_name: string;
  phone: string | null;
  email: string | null;
  status: string;
  created_at: string;
  total_count: number;
}

const PAGE = 50;

export default function AdminUsersPage() {
  const { profile } = useAuth();
  const [role, setRole] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const [adminEmail, setAdminEmail] = useState('');
  const [adminName, setAdminName] = useState('');
  const [adminPass, setAdminPass] = useState('');
  const [notice, setNotice] = useState('');
  const action = useAction();

  const { data, error, loading, reload } = useLiveQuery<UserRow[]>(
    async () =>
      must(
        await supabase().rpc('admin_list_users', { p_role: role || null, p_search: search || null, p_limit: PAGE, p_offset: page * PAGE }),
      ) as UserRow[],
    [role, search, page],
  );

  const setStatus = (u: UserRow, status: string) =>
    action.run(async () => {
      must(await supabase().from('profiles').update({ status }).eq('id', u.id));
      await reload();
    });

  // يدّي أو يشيل صلاحية المدير بالإيميل (بيشتغل حتى لو الحساب متسجل في برنامج تاني على نفس Supabase)
  const setRoleByEmail = (email: string, newRole: 'admin' | 'client' | 'store_owner') =>
    action.run(async () => {
      setNotice('');
      must(await supabase().rpc('admin_set_role_by_email', { p_email: email, p_role: newRole }));
      setNotice(newRole === 'admin' ? `تمام، ${showId(email)} بقى مدير زيك` : `اتشالت صلاحية المدير من ${showId(email)}`);
      await reload();
    });

  // زي خير بلدنا: تكتب الإيميل وباسورد، فيتعمله حساب ويبقى مدير ويدخل على طول
  const addAdmin = () =>
    action.run(async () => {
      setNotice('');
      const em = adminEmail.trim().toLowerCase();
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(em)) throw new Error('اكتب إيميل صحيح');
      const r = await tempClient().auth.signUp({
        email: em,
        password: adminPass,
        options: { data: { app: APP_TAG, full_name: adminName.trim() || 'مدير', role: 'client' } },
      });
      const existed = !!r.error && /already|registered|exists/i.test(r.error.message);
      if (r.error && !existed) throw r.error;
      must(await supabase().rpc('admin_set_role_by_email', { p_email: em, p_role: 'admin' }));
      setNotice(
        existed
          ? `${showId(em)} كان عنده حساب قبل كده، وبقى مدير. يدخل بالباسورد بتاعه.`
          : `اتضاف المدير. يدخل بـ ${showId(em)} والباسورد اللي كتبته.`,
      );
      setAdminEmail('');
      setAdminName('');
      setAdminPass('');
      await reload();
    });

  const total = data?.[0]?.total_count ?? 0;

  return (
    <>
      <PageHeader title="المستخدمون" subtitle={`${total} مستخدم`} />
      <Card className="mb-5">
        <div className="mb-2 font-bold">➕ إضافة مدير معاك</div>
        <p className="mb-3 text-sm text-gray-600">
          اكتب اسمه وإيميله وباسورد، هيبقى مدير زيك ويدخل بيهم على طول من صفحة الدخول.
        </p>
        <form
          className="grid gap-3 sm:grid-cols-2"
          onSubmit={(e) => {
            e.preventDefault();
            addAdmin();
          }}
        >
          <Input placeholder="الاسم" value={adminName} onChange={(e) => setAdminName(e.target.value)} />
          <Input dir="ltr" type="email" required placeholder="الإيميل" value={adminEmail} onChange={(e) => setAdminEmail(e.target.value)} />
          <Input dir="ltr" type="text" required minLength={6} placeholder="باسورد (6 حروف أو أكتر)" value={adminPass} onChange={(e) => setAdminPass(e.target.value)} />
          <Button type="submit" disabled={action.busy}>➕ إضافة مدير</Button>
        </form>
        {notice && <div className="mt-3 rounded-xl bg-emerald-50 p-3 text-sm font-semibold text-emerald-800">{notice}</div>}
      </Card>
      <Card>
        <div className="mb-4 flex flex-wrap gap-3">
          <Select value={role} onChange={(e) => { setRole(e.target.value); setPage(0); }} className="w-44">
            <option value="">كل الأدوار</option>
            {Object.entries(roleLabel).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </Select>
          <Input placeholder="بحث بالاسم أو البريد أو الموبايل" value={search} onChange={(e) => { setSearch(e.target.value); setPage(0); }} className="w-72" />
        </div>
        {(error || action.error) && <ErrorBox message={(error || action.error)!} />}
        {loading && !data ? (
          <Spinner />
        ) : (
          <Table head={['الاسم', 'الدور', 'التواصل', 'الحالة', 'التسجيل', '']}>
            {data?.map((u) => (
              <tr key={u.id} className="hover:bg-gray-50">
                <Td className="font-semibold">{u.full_name}</Td>
                <Td>{roleLabel[u.role]}</Td>
                <Td className="text-gray-600">
                  <div dir="ltr" className="text-right">{u.email ? showId(u.email) : ''}</div>
                  <div dir="ltr" className="text-right text-xs">{u.phone}</div>
                </Td>
                <Td>
                  <Badge className={u.status === 'active' ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}>
                    {u.status === 'active' ? 'نشط' : u.status === 'suspended' ? 'موقوف' : u.status}
                  </Badge>
                </Td>
                <Td className="text-gray-500">{fmtDateTime(u.created_at)}</Td>
                <Td className="space-x-2 space-x-reverse whitespace-nowrap">
                  {u.id !== profile?.id && u.email && (
                    u.role === 'admin' ? (
                      <Button variant="secondary" className="px-2 py-1 text-xs" disabled={action.busy} onClick={() => setRoleByEmail(u.email!, 'client')}>
                        شيل المدير
                      </Button>
                    ) : (
                      <Button variant="secondary" className="px-2 py-1 text-xs" disabled={action.busy} onClick={() => setRoleByEmail(u.email!, 'admin')}>
                        اجعله مدير
                      </Button>
                    )
                  )}
                  {u.id !== profile?.id &&
                    (u.status === 'active' ? (
                      <Button variant="danger" className="px-2 py-1 text-xs" disabled={action.busy} onClick={() => setStatus(u, 'suspended')}>
                        إيقاف
                      </Button>
                    ) : (
                      <Button className="px-2 py-1 text-xs" disabled={action.busy} onClick={() => setStatus(u, 'active')}>
                        تفعيل
                      </Button>
                    ))}
                </Td>
              </tr>
            ))}
          </Table>
        )}
        <div className="mt-4 flex justify-between">
          <Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>
            السابق
          </Button>
          <Button variant="secondary" disabled={(page + 1) * PAGE >= total} onClick={() => setPage(page + 1)}>
            التالي
          </Button>
        </div>
      </Card>
    </>
  );
}
