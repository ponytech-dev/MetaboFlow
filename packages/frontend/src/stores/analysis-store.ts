import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import type {
  SampleMetadata,
  PeakDetectionParams,
  EngineType,
  BatchCorrectionMethod,
  StatAnalysisType,
  ExportFormat,
} from '@/types/analysis';

const DEFAULT_PEAK_PARAMS: PeakDetectionParams = {
  ppm: 10,
  peakwidthMin: 5,
  peakwidthMax: 60,
  snthresh: 10,
  noise: 1000,
  prefilter: [3, 100],
};

interface AnalysisState {
  // Navigation
  currentStep: number;

  // Step 1: Data Import
  files: File[];
  sampleMetadata: SampleMetadata[];

  // Step 2: Peak Detection
  selectedEngine: EngineType | null;
  peakParams: PeakDetectionParams;
  multiEngineMode: boolean;

  // Step 3: QC & Batch Correction
  batchMethod: BatchCorrectionMethod;

  // Step 4: Statistical Analysis
  analysisType: StatAnalysisType;
  groupComparison: [string, string] | null;
  fcCutoff: number;
  pValueCutoff: number;

  // Step 5: Metabolite Annotation
  databases: string[];
  ms1Ppm: number;
  useSirius: boolean;

  // Step 6: Pathway Analysis
  pathwayWorkflows: string[];
  organism: string;
  sigThreshold: number;

  // Step 7: Export
  chartTypes: string[];
  exportFormat: ExportFormat;

  // Actions - Navigation
  setStep: (step: number) => void;
  nextStep: () => void;
  prevStep: () => void;

  // Actions - Step 1
  setFiles: (files: File[]) => void;
  addFiles: (files: File[]) => void;
  removeFile: (index: number) => void;
  setSampleMetadata: (metadata: SampleMetadata[]) => void;

  // Actions - Step 2
  setSelectedEngine: (engine: EngineType | null) => void;
  setPeakParams: (params: Partial<PeakDetectionParams>) => void;
  setMultiEngineMode: (enabled: boolean) => void;

  // Actions - Step 3
  setBatchMethod: (method: BatchCorrectionMethod) => void;

  // Actions - Step 4
  setAnalysisType: (type: StatAnalysisType) => void;
  setGroupComparison: (groups: [string, string] | null) => void;
  setFcCutoff: (value: number) => void;
  setPValueCutoff: (value: number) => void;

  // Actions - Step 5
  setDatabases: (dbs: string[]) => void;
  toggleDatabase: (db: string) => void;
  setMs1Ppm: (ppm: number) => void;
  setUseSirius: (use: boolean) => void;

  // Actions - Step 6
  setPathwayWorkflows: (workflows: string[]) => void;
  togglePathwayWorkflow: (workflow: string) => void;
  setOrganism: (organism: string) => void;
  setSigThreshold: (threshold: number) => void;

  // Actions - Step 7
  setChartTypes: (types: string[]) => void;
  toggleChartType: (type: string) => void;
  setExportFormat: (format: ExportFormat) => void;

  // Analysis execution state
  analysisId: string | null;
  isRunning: boolean;
  runError: string | null;

  // Actions - Execution
  setAnalysisId: (id: string | null) => void;
  setIsRunning: (running: boolean) => void;
  setRunError: (error: string | null) => void;

  // Reset
  reset: () => void;
}

const TOTAL_STEPS = 7;

export const useAnalysisStore = create<AnalysisState>()(
  devtools(
    (set) => ({
      // Initial state - Navigation
      currentStep: 1,

      // Step 1
      files: [],
      sampleMetadata: [],

      // Step 2
      selectedEngine: null,
      peakParams: DEFAULT_PEAK_PARAMS,
      multiEngineMode: false,

      // Step 3
      batchMethod: 'SERRF',

      // Step 4
      analysisType: 'PCA',
      groupComparison: null,
      fcCutoff: 2.0,
      pValueCutoff: 0.05,

      // Step 5
      databases: ['HMDB', 'MassBank'],
      ms1Ppm: 10,
      useSirius: false,

      // Step 6
      pathwayWorkflows: ['SMPDB'],
      organism: 'Homo sapiens',
      sigThreshold: 0.05,

      // Step 7
      chartTypes: ['Volcano', 'PCA', 'Heatmap'],
      exportFormat: 'PDF',

      // Execution state
      analysisId: null,
      isRunning: false,
      runError: null,

      // Navigation actions
      setStep: (step) =>
        set({ currentStep: Math.max(1, Math.min(TOTAL_STEPS, step)) }),
      nextStep: () =>
        set((state) => ({
          currentStep: Math.min(TOTAL_STEPS, state.currentStep + 1),
        })),
      prevStep: () =>
        set((state) => ({
          currentStep: Math.max(1, state.currentStep - 1),
        })),

      // Step 1 actions
      setFiles: (files) => set({ files }),
      addFiles: (newFiles) =>
        set((state) => ({ files: [...state.files, ...newFiles] })),
      removeFile: (index) =>
        set((state) => ({
          files: state.files.filter((_, i) => i !== index),
        })),
      setSampleMetadata: (sampleMetadata) => set({ sampleMetadata }),

      // Step 2 actions
      setSelectedEngine: (selectedEngine) => set({ selectedEngine }),
      setPeakParams: (params) =>
        set((state) => ({
          peakParams: { ...state.peakParams, ...params },
        })),
      setMultiEngineMode: (multiEngineMode) => set({ multiEngineMode }),

      // Step 3 actions
      setBatchMethod: (batchMethod) => set({ batchMethod }),

      // Step 4 actions
      setAnalysisType: (analysisType) => set({ analysisType }),
      setGroupComparison: (groupComparison) => set({ groupComparison }),
      setFcCutoff: (fcCutoff) => set({ fcCutoff }),
      setPValueCutoff: (pValueCutoff) => set({ pValueCutoff }),

      // Step 5 actions
      setDatabases: (databases) => set({ databases }),
      toggleDatabase: (db) =>
        set((state) => ({
          databases: state.databases.includes(db)
            ? state.databases.filter((d) => d !== db)
            : [...state.databases, db],
        })),
      setMs1Ppm: (ms1Ppm) => set({ ms1Ppm }),
      setUseSirius: (useSirius) => set({ useSirius }),

      // Step 6 actions
      setPathwayWorkflows: (pathwayWorkflows) => set({ pathwayWorkflows }),
      togglePathwayWorkflow: (workflow) =>
        set((state) => ({
          pathwayWorkflows: state.pathwayWorkflows.includes(workflow)
            ? state.pathwayWorkflows.filter((w) => w !== workflow)
            : [...state.pathwayWorkflows, workflow],
        })),
      setOrganism: (organism) => set({ organism }),
      setSigThreshold: (sigThreshold) => set({ sigThreshold }),

      // Step 7 actions
      setChartTypes: (chartTypes) => set({ chartTypes }),
      toggleChartType: (type) =>
        set((state) => ({
          chartTypes: state.chartTypes.includes(type)
            ? state.chartTypes.filter((t) => t !== type)
            : [...state.chartTypes, type],
        })),
      setExportFormat: (exportFormat) => set({ exportFormat }),

      // Execution actions
      setAnalysisId: (analysisId) => set({ analysisId }),
      setIsRunning: (isRunning) => set({ isRunning }),
      setRunError: (runError) => set({ runError }),

      // Reset
      reset: () =>
        set({
          currentStep: 1,
          files: [],
          sampleMetadata: [],
          selectedEngine: null,
          peakParams: DEFAULT_PEAK_PARAMS,
          multiEngineMode: false,
          batchMethod: 'SERRF',
          analysisType: 'PCA',
          groupComparison: null,
          fcCutoff: 2.0,
          pValueCutoff: 0.05,
          databases: ['HMDB', 'MassBank'],
          ms1Ppm: 10,
          useSirius: false,
          pathwayWorkflows: ['SMPDB'],
          organism: 'Homo sapiens',
          sigThreshold: 0.05,
          chartTypes: ['Volcano', 'PCA', 'Heatmap'],
          exportFormat: 'PDF',
          analysisId: null,
          isRunning: false,
          runError: null,
        }),
    }),
    { name: 'MetaboFlow-Analysis' }
  )
);
