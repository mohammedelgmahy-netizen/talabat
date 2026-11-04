'use client';

import { useState } from 'react';
import { Badge, Button, Card, ErrorBox, Input, PageHeader, Select, Spinner, Table, Td } from '@/components/ui';
import { fmtDateTime, roleLabel } from '@/lib/format';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
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

  const total = data?.[0]?.total_count ?? 0;

  return (
    <>
      <PageHeader title="المستخدمون" subtitle={`${total} مستخدم`} />
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
                  <div dir="ltr" className="text-right">{u.email}</div>
                  <div dir="ltr" className="text-right text-xs">{u.phone}</div>
                </Td>
                <Td>
                  <Badge className={u.status === 'active' ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}>
                    {u.status === 'active' ? 'نشط' : u.status === 'suspended' ? 'موقوف' : u.status}
                  </Badge>
                </Td>
                <Td className="text-gray-500">{fmtDateTime(u.created_at)}</Td>
                <Td>
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
