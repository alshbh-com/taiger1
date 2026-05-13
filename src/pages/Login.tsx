import { useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent } from '@/components/ui/card';
import { Lock, Loader2 } from 'lucide-react';
import logo from '@/assets/logo.png.jpg';

export default function Login() {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!password.trim()) return;
    
    setLoading(true);
    setError('');
    
    const result = await login(password);
    if (result.error) {
      setError(result.error);
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center p-4 relative overflow-hidden">
      {/* Neon orbs */}
      <div className="absolute -top-32 -right-20 w-[520px] h-[520px] rounded-full bg-primary/20 blur-[140px] animate-neon-pulse" />
      <div className="absolute -bottom-32 -left-20 w-[460px] h-[460px] rounded-full bg-secondary/20 blur-[140px] animate-neon-pulse" />
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[280px] h-[280px] rounded-full bg-accent/10 blur-[100px]" />

      <Card className="w-full max-w-md relative z-10 glass-effect border-primary/40 shadow-glow overflow-hidden scanline">
        {/* Top neon strip */}
        <div className="h-1 w-full gradient-neon" />
        <CardContent className="pt-10 pb-8 px-8">
          <div className="text-center mb-8">
            <div className="relative mx-auto w-28 h-28 mb-5">
              <div className="absolute inset-0 rounded-2xl gradient-neon blur-xl opacity-80 animate-neon-pulse" />
              <img src={logo} alt="تايجر" className="relative h-28 w-28 rounded-2xl object-cover ring-2 ring-primary/70" />
            </div>
            <h1 className="font-display text-4xl font-black neon-text animate-flicker">TIGER</h1>
            <div className="mt-2 flex items-center justify-center gap-2">
              <span className="h-px w-8 bg-secondary/60" />
              <p className="text-xs tracking-[0.4em] neon-text-magenta uppercase">نظام الشحن</p>
              <span className="h-px w-8 bg-secondary/60" />
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="relative group">
              <Lock className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-primary" />
              <Input
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="h-12 pr-10 text-base bg-input/70 border-primary/40 focus:border-primary focus:ring-2 focus:ring-primary/40 placeholder:text-muted-foreground/50 font-mono tracking-widest"
                dir="ltr"
                autoFocus
              />
              <div className="pointer-events-none absolute inset-0 rounded-md ring-1 ring-primary/0 group-focus-within:ring-primary/60 transition-all" />
            </div>

            {error && (
              <p className="text-sm text-destructive text-center bg-destructive/10 border border-destructive/40 py-2 rounded-md">
                {error}
              </p>
            )}

            <Button
              type="submit"
              className="w-full h-12 text-base font-bold gradient-neon text-background hover:opacity-90 border-0 shadow-glow tracking-widest font-display"
              disabled={loading}
            >
              {loading ? <Loader2 className="h-5 w-5 animate-spin" /> : 'ENTER'}
            </Button>
          </form>

          <div className="mt-6 text-center text-[10px] tracking-[0.3em] text-muted-foreground uppercase">
            // secured channel · v2.0
          </div>
        </CardContent>
      </Card>

      {/* Made-by bar — full width */}
      <a
        href="https://wa.me/201061067966"
        target="_blank"
        rel="noopener noreferrer"
        className="absolute bottom-0 left-0 right-0 z-20 group"
      >
        <div className="relative">
          <div className="absolute inset-0 gradient-neon opacity-30 group-hover:opacity-60 transition-opacity blur-sm" />
          <div className="relative flex items-center justify-center gap-3 px-4 py-3 bg-card/90 backdrop-blur border-t border-primary/50 shadow-glow flex-wrap">
            <span className="h-2 w-2 rounded-full bg-accent animate-neon-pulse shrink-0" />
            <span className="text-xs sm:text-sm font-semibold neon-text font-display tracking-wider">
              صُنع من شركة دوبامين (الشبح سابقاً)
            </span>
            <span className="text-[10px] sm:text-xs text-secondary neon-text-magenta">
              · واتساب 01061067966
            </span>
          </div>
        </div>
      </a>
    </div>
  );
}
