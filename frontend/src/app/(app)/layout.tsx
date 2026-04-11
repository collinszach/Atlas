import { Sidebar } from "@/components/layout/Sidebar";
import { TooltipProvider } from "@/components/ui/Tooltip";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <TooltipProvider>
      <div className="flex h-screen w-screen overflow-hidden bg-atlas-bg">
        <Sidebar />
        <main className="relative flex-1 overflow-hidden">{children}</main>
      </div>
    </TooltipProvider>
  );
}
