import { LoginForm } from '@/components/login-form';

// لينك دخول المديرين: إيميل وباسورد بس من غير تسجيل محل
export default function AdminLoginPage() {
  return <LoginForm adminOnly />;
}
