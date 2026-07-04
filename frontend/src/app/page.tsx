import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { LandingHero } from "@/components/landing/LandingHero";

export default async function LandingPage() {
  const { userId } = await auth();

  if (userId) {
    redirect("/map");
  }

  return <LandingHero />;
}
