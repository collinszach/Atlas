import { SignIn } from "@clerk/nextjs";

export default function SignInPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-atlas-bg">
      <div className="flex flex-col items-center gap-6">
        <h1 className="font-display text-3xl font-semibold text-atlas-accent">Atlas</h1>
        <p className="text-atlas-muted text-sm">Your travel intelligence platform</p>
        <SignIn />
      </div>
    </div>
  );
}
