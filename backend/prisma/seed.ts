import { PrismaClient, RoleType } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const roles = [
    { name: RoleType.SUPER_ADMIN, description: 'System-wide super administrator' },
    { name: RoleType.ADMIN, description: 'Masjid administrator with full masjid control' },
    { name: RoleType.FINANCE, description: 'Finance volunteer managing contributions and collections' },
    { name: RoleType.ANNOUNCEMENT, description: 'Volunteer managing masjid announcements' },
  ];

  for (const role of roles) {
    await prisma.role.upsert({
      where: { name: role.name },
      update: { description: role.description },
      create: role,
    });
  }

  const rawPhone = process.env.BOOTSTRAP_SUPER_ADMIN_PHONE?.trim();
  if (rawPhone) {
    const digits = rawPhone.replace(/\D/g, '');
    const phone = rawPhone.startsWith('+') ? `+${digits}` : `+91${digits.slice(-10)}`;
    const name = process.env.BOOTSTRAP_SUPER_ADMIN_NAME?.trim() || 'Super Admin';
    await prisma.user.upsert({
      where: { phone },
      update: { name, isSuperAdmin: true, isActive: true, isOnboarded: true },
      create: { phone, name, isSuperAdmin: true, isActive: true, isOnboarded: true },
    });
  }
}

main()
  .catch((error) => {
    console.error('Database role setup failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
