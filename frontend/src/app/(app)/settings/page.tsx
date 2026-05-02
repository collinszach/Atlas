"use client";

import { useEffect, useState } from "react";
import { useCurrentUser, useUpdateProfile } from "@/hooks/useUser";

export default function SettingsPage() {
  const { data: user, isLoading } = useCurrentUser();
  const { mutateAsync: updateProfile, isPending, isSuccess, isError } = useUpdateProfile();

  const [displayName, setDisplayName] = useState("");
  const [homeCountry, setHomeCountry] = useState("");

  useEffect(() => {
    if (user) {
      setDisplayName(user.display_name ?? "");
      setHomeCountry(user.home_country ?? "");
    }
  }, [user]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    await updateProfile({
      display_name: displayName.trim() || null,
      home_country: homeCountry.trim().toUpperCase().slice(0, 2) || null,
    });
  }

  if (isLoading) {
    return <div className="p-6 text-atlas-muted text-sm">Loading...</div>;
  }

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-lg mx-auto">
        <h1 className="font-display text-2xl font-semibold text-atlas-text mb-1">Settings</h1>
        <p className="text-sm text-atlas-muted mb-8">Manage your account profile.</p>

        <form onSubmit={handleSave} className="flex flex-col gap-6">
          {/* Read-only email */}
          <div>
            <label className="text-xs text-atlas-muted uppercase tracking-widest mb-1.5 block">
              Email
            </label>
            <p className="text-sm text-atlas-text font-mono bg-atlas-surface border border-atlas-border rounded px-3 py-2">
              {user?.email}
            </p>
          </div>

          {/* Display name */}
          <div>
            <label
              htmlFor="display_name"
              className="text-xs text-atlas-muted uppercase tracking-widest mb-1.5 block"
            >
              Display name
            </label>
            <input
              id="display_name"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              placeholder="Your name"
              className="w-full rounded border border-atlas-border bg-atlas-surface px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
            />
          </div>

          {/* Home country */}
          <div>
            <label
              htmlFor="home_country"
              className="text-xs text-atlas-muted uppercase tracking-widest mb-1.5 block"
            >
              Home country
            </label>
            <input
              id="home_country"
              value={homeCountry}
              onChange={(e) => setHomeCountry(e.target.value.toUpperCase().slice(0, 2))}
              placeholder="US"
              maxLength={2}
              className="w-24 rounded border border-atlas-border bg-atlas-surface px-3 py-2 text-sm text-atlas-text font-mono placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent uppercase"
            />
            <p className="text-xs text-atlas-muted mt-1">ISO 3166-1 alpha-2 code (e.g. US, GB, JP)</p>
          </div>

          <div className="flex items-center gap-4">
            <button
              type="submit"
              disabled={isPending}
              className="px-4 py-2 rounded bg-atlas-accent text-atlas-bg text-sm font-medium hover:bg-atlas-accent/80 transition-colors disabled:opacity-50"
            >
              {isPending ? "Saving…" : "Save changes"}
            </button>
            {isSuccess && (
              <span className="text-xs text-green-400">Saved.</span>
            )}
            {isError && (
              <span className="text-xs text-red-400">Save failed. Try again.</span>
            )}
          </div>
        </form>
      </div>
    </div>
  );
}
