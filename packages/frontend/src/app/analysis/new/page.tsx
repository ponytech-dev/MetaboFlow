import { WizardShell } from '@/components/wizard';

export const metadata = {
  title: 'New Analysis — MetaboFlow',
};

export default function NewAnalysisPage() {
  return (
    <div className="mx-auto max-w-screen-xl px-6 py-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">新建分析</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          按步骤配置代谢组学分析流程，完成后一键生成报告。
        </p>
      </div>
      <WizardShell />
    </div>
  );
}
