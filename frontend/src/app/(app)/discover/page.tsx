"use client";

import { useState } from "react";
import { Sparkles, MapPin, ChevronRight, X, Loader2 } from "lucide-react";
import { useRecommendations, useDestinationBrief } from "@/hooks/useDiscover";
import type { Recommendation, DestinationBriefResponse, RecommendationPreferences } from "@/types";

const MONTH_NAMES = [
  "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

const CLIMATE_OPTIONS = ["warm", "cool", "tropical", "temperate", "any"];
const BUDGET_OPTIONS = ["budget", "moderate", "luxury"];
const INTEREST_OPTIONS = ["food", "history", "hiking", "beaches", "culture", "nightlife", "wildlife", "architecture"];

function RecommendationCard({
  rec,
  onViewBrief,
}: {
  rec: Recommendation;
  onViewBrief: (rec: Recommendation) => void;
}) {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface p-5 flex flex-col gap-3">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="text-base font-semibold text-atlas-text font-display">
            {rec.city ? `${rec.city}, ${rec.country}` : rec.country}
          </h3>
          {rec.country_code && (
            <span className="text-xs font-mono text-atlas-muted">{rec.country_code}</span>
          )}
        </div>
        <span className="text-xs font-mono px-2 py-0.5 rounded border border-atlas-border text-atlas-muted capitalize shrink-0">
          {rec.rough_cost}
        </span>
      </div>

      <p className="text-sm text-atlas-text leading-relaxed">{rec.why_youll_love_it}</p>

      <div className="flex flex-col gap-1 text-xs text-atlas-muted">
        <span><span className="text-atlas-accent font-mono">Best time:</span> {rec.best_time}</span>
        <span><span className="text-atlas-accent font-mono">Getting there:</span> {rec.getting_there}</span>
      </div>

      <button
        onClick={() => onViewBrief(rec)}
        className="mt-1 flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors self-start"
      >
        View destination brief
        <ChevronRight size={12} />
      </button>
    </div>
  );
}

function BriefPanel({
  brief,
  onClose,
}: {
  brief: DestinationBriefResponse;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-y-0 right-0 w-full max-w-md bg-atlas-surface border-l border-atlas-border overflow-y-auto z-50 shadow-2xl">
      <div className="flex items-center justify-between p-5 border-b border-atlas-border sticky top-0 bg-atlas-surface">
        <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
          {brief.destination}
        </h2>
        <button
          onClick={onClose}
          className="text-atlas-muted hover:text-atlas-text transition-colors"
        >
          <X size={16} />
        </button>
      </div>

      <div className="p-5 flex flex-col gap-5">
        <p className="text-sm text-atlas-text leading-relaxed">{brief.overview}</p>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Best Months</h3>
          <div className="flex gap-1.5 flex-wrap">
            {brief.best_months.map((m) => (
              <span key={m} className="text-xs font-mono px-2 py-0.5 rounded bg-atlas-bg border border-atlas-border text-atlas-text">
                {MONTH_NAMES[m]}
              </span>
            ))}
          </div>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Visa & Entry</h3>
          <p className="text-sm text-atlas-text">{brief.visa_notes}</p>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Rough Costs</h3>
          <p className="text-sm text-atlas-text">{brief.rough_costs}</p>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Must Do</h3>
          <ul className="flex flex-col gap-1">
            {brief.must_do.map((item, i) => (
              <li key={i} className="text-sm text-atlas-text flex items-start gap-2">
                <MapPin size={10} className="text-atlas-accent mt-1 shrink-0" />
                {item}
              </li>
            ))}
          </ul>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Food Highlights</h3>
          <ul className="flex flex-col gap-1">
            {brief.food_highlights.map((item, i) => (
              <li key={i} className="text-sm text-atlas-text">· {item}</li>
            ))}
          </ul>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Getting Around</h3>
          <p className="text-sm text-atlas-text">{brief.transport_within}</p>
        </section>
      </div>
    </div>
  );
}

export default function DiscoverPage() {
  const [climate, setClimate] = useState("");
  const [budget, setBudget] = useState("");
  const [month, setMonth] = useState("");
  const [selectedInterests, setSelectedInterests] = useState<string[]>([]);
  const [region, setRegion] = useState("");
  const [activeBrief, setActiveBrief] = useState<DestinationBriefResponse | null>(null);

  const recommend = useRecommendations();
  const getBrief = useDestinationBrief();

  function toggleInterest(interest: string) {
    setSelectedInterests((prev) =>
      prev.includes(interest) ? prev.filter((i) => i !== interest) : [...prev, interest]
    );
  }

  async function handleRecommend() {
    const prefs: RecommendationPreferences = {};
    if (climate) prefs.climate = climate;
    if (budget) prefs.budget = budget;
    if (month) prefs.travel_month = month;
    if (selectedInterests.length > 0) prefs.interests = selectedInterests;
    if (region) prefs.departure_region = region;
    await recommend.mutateAsync({ preferences: prefs, already_visited: [] });
  }

  async function handleViewBrief(rec: Recommendation) {
    const brief = await getBrief.mutateAsync({
      country: rec.country,
      country_code: rec.country_code ?? undefined,
      city: rec.city ?? undefined,
    });
    setActiveBrief(brief);
  }

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-3xl mx-auto">
        <div className="mb-8">
          <h1 className="text-xl font-semibold text-atlas-text font-display mb-1">Discover</h1>
          <p className="text-sm text-atlas-muted">AI-powered destination recommendations based on your preferences.</p>
        </div>

        <div className="rounded-lg border border-atlas-border bg-atlas-surface p-5 mb-6 flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
            <div>
              <label className="text-xs text-atlas-muted mb-1 block">Climate</label>
              <select
                value={climate}
                onChange={(e) => setClimate(e.target.value)}
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text focus:outline-none focus:border-atlas-accent"
              >
                <option value="">Any</option>
                {CLIMATE_OPTIONS.map((c) => (
                  <option key={c} value={c} className="capitalize">{c.charAt(0).toUpperCase() + c.slice(1)}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-xs text-atlas-muted mb-1 block">Budget</label>
              <select
                value={budget}
                onChange={(e) => setBudget(e.target.value)}
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text focus:outline-none focus:border-atlas-accent"
              >
                <option value="">Any</option>
                {BUDGET_OPTIONS.map((b) => (
                  <option key={b} value={b} className="capitalize">{b.charAt(0).toUpperCase() + b.slice(1)}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-xs text-atlas-muted mb-1 block">Travel Month</label>
              <select
                value={month}
                onChange={(e) => setMonth(e.target.value)}
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text focus:outline-none focus:border-atlas-accent"
              >
                <option value="">Any</option>
                {MONTH_NAMES.slice(1).map((m, i) => (
                  <option key={i + 1} value={m}>{m}</option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="text-xs text-atlas-muted mb-2 block">Interests</label>
            <div className="flex flex-wrap gap-2">
              {INTEREST_OPTIONS.map((interest) => (
                <button
                  key={interest}
                  onClick={() => toggleInterest(interest)}
                  className={`px-3 py-1 text-xs rounded-full border transition-colors capitalize ${
                    selectedInterests.includes(interest)
                      ? "border-atlas-accent bg-atlas-accent/10 text-atlas-accent"
                      : "border-atlas-border text-atlas-muted hover:border-atlas-accent/40"
                  }`}
                >
                  {interest}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="text-xs text-atlas-muted mb-1 block">Departure Region (optional)</label>
            <input
              value={region}
              onChange={(e) => setRegion(e.target.value)}
              placeholder="e.g. North America, Western Europe"
              className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
            />
          </div>

          <button
            onClick={handleRecommend}
            disabled={recommend.isPending}
            className="flex items-center justify-center gap-2 px-4 py-2.5 rounded bg-atlas-accent text-atlas-bg text-sm font-medium hover:bg-atlas-accent/80 transition-colors disabled:opacity-50"
          >
            {recommend.isPending ? (
              <>
                <Loader2 size={14} className="animate-spin" />
                Thinking&hellip;
              </>
            ) : (
              <>
                <Sparkles size={14} />
                Get Recommendations
              </>
            )}
          </button>

          {recommend.isError && (
            <p className="text-xs text-red-400">Failed to get recommendations. Try again.</p>
          )}
        </div>

        {recommend.data && (
          <div className="flex flex-col gap-4">
            {recommend.data.map((rec, i) => (
              <RecommendationCard key={i} rec={rec} onViewBrief={handleViewBrief} />
            ))}
          </div>
        )}

        {getBrief.isPending && (
          <div className="fixed inset-0 bg-atlas-bg/60 flex items-center justify-center z-40">
            <Loader2 size={24} className="animate-spin text-atlas-accent" />
          </div>
        )}
      </div>

      {activeBrief && (
        <BriefPanel brief={activeBrief} onClose={() => setActiveBrief(null)} />
      )}
    </div>
  );
}
