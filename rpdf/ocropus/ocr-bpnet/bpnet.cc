// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
// or its licensors, as applicable.
//
// You may not use this file except under the terms of the accompanying license.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you
// may not use this file except in compliance with the License. You may
// obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Project:  ocr-bpnet - neural network classifier
// File: bpnet.cc
// Purpose: neural network classifier
// Responsible: Hagen Kaprykowsky (kapry@iupr.net)
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "bpnet.h"
#include "ocr-utils.h"
#include "confusion-matrix.h"

using namespace ocropus;
using namespace colib;

namespace iupr_bpnet {

#define MIN_SCORE 1e-6
#define epsilon_stdev 1e-04

    template<class T>
    bool valid(T &v) {
        for(int i=0;i<v.length1d();i++)
            if(isnan(v.at1d(i))) {
            	//printf("[");print(v);printf("]\n");
                return false;                
            }
        return true;
    }

    void shuffle_feat(objlist<floatarray> &v,intarray &c) {
        floatarray v_tmp;
        v_tmp.resize(v[0].length());
        int c_tmp;

        int n = v.length();
        for(int i=0;i<n-1;i++) {
            int target = rand()%(n-i)+i;
            copy(v_tmp,v[target]);
            copy(v[target],v[i]);
            copy(v[i],v_tmp);
            c_tmp = c[target];
            c[target] = c[i];
            c[i] = c_tmp;
        }
    }

    void write(FILE *stream,floatarray &input) {
        for(int i=0;i<input.length1d();i++) {
            fprintf(stream,"%.10g\n",double(input.at1d(i)));
        }
    }
    void read(floatarray &output,FILE *stream) {
        float value;
        for(int i=0;i<output.length1d();i++) {
            if(fscanf(stream,"%g",&value)!=1) {
                throw "bad file";
                return;
            }
            output.at1d(i) = value;
        }
    }

    // not to be used outside this scope
#define NSIGMOID 10000
#define SIGMOID_RANGE 15.0

    // table of the sigmoid function
    static floatarray sigmoid_table(NSIGMOID);

    // slow exponential sigmoid function, not tabulated
    static float slow_sigmoid(float x) {
        return 1.0/(1.0+exp(-x));
    }

    // initialize the simgoid table
    static void init_sigmoid_table() {
        int i;
        for(i=0;i<NSIGMOID;i++) {
            sigmoid_table(i) = slow_sigmoid(i*SIGMOID_RANGE/NSIGMOID);
        }
    }

    // tabulated sigmoid function
    static inline float sigmoid(float x,bool &inited) {
        float abs_x = (x<0.0)?-x:x;
        int index;
        float abs_result;

        if (!inited) {
            init_sigmoid_table();
            inited = true;
        }

        if(abs_x>=20.0) {
            abs_result = 1.0;
        } else {
            index = int(NSIGMOID*abs_x/SIGMOID_RANGE);
            if(index>=NSIGMOID) {
                abs_result = 1.0;
            } else {
                abs_result = sigmoid_table(index);
            }
        }

        if(x<0.0) {
            return 1.0-abs_result;
        } else {
            return abs_result;
        }
    }

    // float random number between low and high
    static float random_range(float low,float high) {
        //drand48 is obsolete, replaced by rand():
        float rnd = float(rand())/float(RAND_MAX);
        return (rnd * (high-low) + low);
    }

    // push activations one layer up using 2d weight matrix
    void bp_propagate_activations(floatarray &activations_input,int ninput,
                                  floatarray &activations_output,int noutput,
                                  floatarray &weights,floatarray &offsets,
                                  bool &sigmoid_inited) {
        float total;

        for(int i=0;i<noutput;i++) {
            total = offsets(i);
            for(int j=0;j<ninput;j++) {
                total += weights(i,j)*activations_input(j);
            }
            activations_output(i) = sigmoid(total,sigmoid_inited);
        }
    }

    // determine hidden layer error from error at the output units.
    void bp_propagate_deltas(floatarray &deltas_input,int noutput,
                             floatarray &activations_input,
                             floatarray &delta_output,int ninput,
                             floatarray &weights) {

        for(int j=0;j<ninput;j++) {
            float deriv = activations_input(j)*(1.0-activations_input(j));
            float total = 0.0;
            if(deriv<1e-5) deriv=1e-5;
            for(int i=0;i<noutput;i++)
                total += delta_output(i)*weights(i,j);
            deltas_input(j) = deriv*total;
        }
    }

    // weight update using backpropagation formula
    void bp_update_weights(floatarray &offsets,floatarray &delta_output,int
                           noutput,floatarray &activation_input,int ninput,
                           floatarray &weights,float eta) {


        for(int i=0;i<noutput;i++) {
            for(int j=0;j<ninput;j++) {
                weights(i,j) += eta*delta_output(i)*activation_input(j);
            }
            offsets(i) += eta*delta_output(i);
        }
    }

    // scale every dimension of the input
    // down to mean=0, std_dev=1
    void normalize_input_train(objlist<floatarray> &vectors,doublearray
                               &stdev,doublearray &m_x) {
	
        CHECK_ARG(stdev.length()==m_x.length());
        int nsamples = vectors.length();
		CHECK_CONDITION(nsamples>0);
        int ninput = m_x.length();
        doublearray m_xx;
        m_xx.resize(ninput);
        fill(m_xx,0.0f);
        fill(m_x,0.0f);
        fill(stdev,0.0f);
        
        for(int d=0;d<ninput;d++) {

            // calc mean and empirical variance
            for(int n=0;n<nsamples;n++) {
                m_x(d)  += vectors[n](d);
            }
            m_x(d) /= nsamples;
            for(int n=0;n<nsamples;n++) {
            	double t = vectors[n](d) - m_x(d);
                m_xx(d) += t * t;
            }            
            m_xx(d) /= nsamples;
			double sqr_stdev = m_xx(d);
			if (sqr_stdev < 0.)
				sqr_stdev = 0.;
            stdev(d) = sqrt(sqr_stdev);
            // normalize
            for(int n=0;n<nsamples;n++) {
                if(stdev(d)>epsilon_stdev) {
                    vectors[n](d) = (vectors[n](d)-m_x(d))/stdev(d);
                } else {
                    vectors[n](d) = vectors[n](d)-m_x(d);        // var = 0: all the same;
                }
            }

        } // end dim loop
        ASSERT(valid(m_x));
       	ASSERT(valid(stdev));
    } // end normalize_input

    void normalize_input_retrain(objlist<floatarray> &vectors,doublearray
                                 &stdev,doublearray &m_x) {

        CHECK_ARG(stdev.length()==m_x.length());
        int ninput = m_x.length();
        int nsamples = vectors.length();

        for(int d=0;d<ninput;d++) {

            // normalize
            for(int n=0;n<nsamples;n++) {
                if(stdev(d)>epsilon_stdev) {
                    vectors[n](d) = (vectors[n](d)-m_x(d))/stdev(d);
                }
                else {
                    vectors[n](d) = vectors[n](d)-m_x(d); //var=0: all the same;
                }
            }
        }
    }


#undef NSIGMOID
#undef SIGMOID_RANGE

    class BpnetClassifier : public Classifier {
    public:
        objlist<floatarray> vectors;
        narray<int> classes;
        narray<float> input;
        narray<float> hidden;
        narray<float> output;
        narray<float> hidden_deltas;
        narray<float> output_deltas;
        narray<float> weights_hidden_input;
        narray<float> hidden_offsets;
        narray<float> weights_output_hidden;
        narray<float> output_offsets;
        narray<float> error;
        narray<double> stdev;
        narray<double> m_x;
        bool init;
        bool sigmoid_inited;
        bool training;
        bool norm;
        bool shuffle;
        int ninput;
        int nhidden;
        int noutput;
        int epochs;
        float learningrate;
        float testportion;
        autodel<ConfusionMatrix> confusion;

        bool filedump;
        stdio fp;
        char buf[1000];
        narray<float> weights_hidden_input_best;
        narray<float> hidden_offsets_best;
        narray<float> weights_output_hidden_best;
        narray<float> output_offsets_best;

        // from Classifier
        BpnetClassifier() {
            filedump = false;
            init = false;
            sigmoid_inited = false;
            training = false;
            norm = true;
            shuffle = true;
            ninput = -1;
            nhidden = -1;
            noutput = -1;
            epochs = -1;
            learningrate = -1.0f;
            testportion = 0.0f;
        }

        BpnetClassifier(const char* path) {
            strncpy(buf,path,sizeof(buf));
            filedump = true;
            init = false;
            sigmoid_inited = false;
            training = false;
            norm = true;
            shuffle = true;
            ninput = -1;
            nhidden = -1;
            noutput = -1;
            epochs = -1;
            learningrate = -1.0f;
            testportion = 0.0f;
        }

        void param(const char *name,double value) {
            if(!strcmp(name,"ninput")) ninput = int(value);
            else if(!strcmp(name,"nhidden")) nhidden = int(value);
            else if(!strcmp(name,"noutput")) noutput = int(value);
            else if(!strcmp(name,"epochs")) epochs = int(value);
            else if(!strcmp(name,"learningrate")) learningrate = float(value);
            else if(!strcmp(name,"testportion")) testportion = float(value);
            else if(!strcmp(name,"normalize")) norm = bool(value);
            else if(!strcmp(name,"shuffle")) shuffle = bool(value);
            else if(!strcmp(name,"filedump")) filedump = bool(value);
            else throw "unknown parameter name";
        }

        void add(floatarray &v,int c) {
            CHECK_CONDITION(training);
            ASSERT(valid(v));
            if(ninput<0) ninput = v.dim(0); else CHECK_CONDITION(v.dim(0)==ninput);

            copy(vectors.push(),v);
            classes.push(c);
            ASSERT(vectors.length()==classes.length());
        }

        void start_training()  {
            training = true;
        }

        void start_classifying() {
            if(training) {
                if(noutput == -1)
                    noutput = max(classes) + 1;
                create();
                if(norm) {
                    if(init) {
                        normalize_input_retrain(vectors,stdev,m_x);
                    }
                    else {
                        normalize_input_train(vectors,stdev,m_x);
                    }
                }
                if(shuffle) {
                    shuffle_feat(vectors,classes);
                }
                init_backprop(0.001);
                train();
                dealloc_train();
                init = true;
            }

            training = false;
        }

        void seal() {
            vectors.dealloc();
            classes.dealloc();
        }

        void score(floatarray &result,floatarray &v) {
            CHECK_CONDITION(!training);
            if(v.length() != ninput) {
                throw_fmt("trained with input dimension %d, but got %d",
                           ninput, v.length());
            }
            result.resize(noutput);
            if(norm) {
                normalize_input_classify(v,stdev,m_x);
            }
            copy(input,v);
            forward();
            // Copy output layer to result avoiding scores less than MIN_SCORE
            for(int i=0;i<output.length();i++) {
                if(output(i)<MIN_SCORE) {
                    result(i) = MIN_SCORE;
                }
                else {
                    result(i) = output(i);
                }
            }
        }

        void save(FILE *stream) {
            CHECK_CONDITION(!training||filedump);
            if(!stream) {
                throw "cannot open output file for bp3 for writing";
            }
            fprintf(stream,"bp3-net %d %d %d %d\n",ninput,nhidden,noutput,norm);
            if(norm) {
                // write mean and variance
                for (int d=0;d<ninput;d++) {
                    fprintf(stream,"%f %f\n",m_x(d),stdev(d));
                }
                ASSERT(valid(m_x));
                ASSERT(valid(stdev));
            }
            write(stream,weights_hidden_input);
            write(stream,hidden_offsets);
            write(stream,weights_output_hidden);
            write(stream,output_offsets);
        }

        void load(FILE *stream) {
            CHECK_CONDITION(!training);
            double m_x_tmp,stdev_tmp;
            int norm_tmp;
            if(!stream) {
                throw "bad input format";
            }

            if(fscanf(stream,"bp3-net %d %d %d %d",&ninput,&nhidden,&noutput,&norm_tmp)!=4 ||
               ninput<1||ninput>1000000||nhidden<1||nhidden>1000000||noutput<1||
               noutput>1000000) {
                throw "bad input format";
            }
            norm = bool(norm_tmp);
            create();
            if(norm) {
                // read mean and variance
                for(int d=0;d<ninput;d++) {
                    fscanf(stream,"%lf %lf\n",&m_x_tmp,&stdev_tmp);
                    m_x(d) = m_x_tmp;
                    stdev(d) = stdev_tmp;
                }
                ASSERT(valid(m_x));
                ASSERT(valid(stdev));
            }
            read(weights_hidden_input,stream);
            read(hidden_offsets,stream);
            read(weights_output_hidden,stream);
            read(output_offsets,stream);
            init = true;
        }

        void create() {
            if(!init) {
                weights_hidden_input.resize(nhidden,ninput);
                weights_output_hidden.resize(noutput,nhidden);
                hidden_offsets.resize(nhidden);
                output_offsets.resize(noutput);
                input.resize(ninput);
                hidden.resize(nhidden);
                output.resize(noutput);
                confusion = make_ConfusionMatrix(noutput);
                m_x.resize(ninput);
                stdev.resize(ninput);
            }
        }

        void train() {
            CHECK_CONDITION(learningrate>0.0f);
            ASSERT(testportion>=0.0f&&testportion<=1.0f);
            int predicted = -1;
            int cls = -1;
            float trainerror;
            float testerror;
            float besttesterror = 1000000.0f;
            float besttrainerror = 1000000.0f;
            int ntrain = int(float(vectors.length())*(1.0f-testportion));
            int ntest = vectors.length()-ntrain;
            float E;
			printf("ep:%d nh:%d lr:%g tp:%g\n", epochs, nhidden, learningrate, testportion);
            printf("=== Start training on %d samples for %d epochs ===\n",ntrain,epochs);
            for(int epoch=0;epoch<epochs;epoch++) {
                printf("Epoch: %d\n",epoch);
                confusion->clear();
                trainerror = 0.0f;
                E = 0.0f;
                for(int sample_index=0;sample_index<ntrain;sample_index++) {
                    copy(input,vectors[sample_index]);
                    forward();
                    for(int k=0;k<noutput;k++) {
                        E += error(k)*error(k);
                    }
                    backward(classes(sample_index));
                    update();
                    predicted = argmax(output);
                    ASSERT(predicted>=0&&predicted<noutput);
                    cls = classes(sample_index);
                    confusion->increment(cls,predicted);
                    trainerror += (predicted!=cls);
                }
                trainerror /= (float(ntrain));
                printf("Training error: %f \t E: %f\n",trainerror,E);
                if(testportion>0.0f) {
                    confusion->clear();
                    testerror = 0.0f;
                    for(int sample_index=ntrain;sample_index<vectors.length();sample_index++) {
                        copy(input,vectors[sample_index]);
                        forward();
                        predicted = argmax(output);
                        ASSERT(predicted>=0&&predicted<noutput);
                        cls = classes(sample_index);
                        confusion->increment(cls,predicted);
                        testerror += (predicted!=cls);
                    }
                    testerror /= (float(ntest));
                    if(besttesterror>testerror) {
                        if(filedump) {
                            copy(weights_hidden_input_best,weights_hidden_input);
                            copy(hidden_offsets_best,hidden_offsets);
                            copy(weights_output_hidden_best,weights_output_hidden);
                            copy(output_offsets_best,hidden_offsets);
                            save(stdio(buf, "w"));
                        }
                        besttesterror = testerror;
                    }
                    printf("Test error:     %f \t Best test error: %f\n",testerror,besttesterror);
                }
                else {
                    if(besttrainerror>trainerror) {
                        if(filedump) {
                            copy(weights_hidden_input_best,weights_hidden_input);
                            copy(hidden_offsets_best,hidden_offsets);
                            copy(weights_output_hidden_best,weights_output_hidden);
                            copy(output_offsets_best,hidden_offsets);
                            save(stdio(buf, "w"));
                        }
                        besttrainerror = trainerror;
                    }
                }
            }
            if(filedump) {
                copy(weights_hidden_input,weights_hidden_input_best);
                copy(hidden_offsets,hidden_offsets_best);
                copy(weights_output_hidden,weights_output_hidden_best);
                copy(output_offsets,hidden_offsets_best);
            }
        }

        void init_backprop(float range) {

            error.resize(noutput);
            hidden_deltas.resize(nhidden);
            output_deltas.resize(noutput);
            fill(error,0.0f);
            fill(hidden_deltas,0.0f);
            fill(output_deltas,0.0f);
            if(!init) {
                for(int i=0;i<nhidden;i++) {
                    for(int j=0;j<ninput;j++) {
                        weights_hidden_input(i,j) = random_range(-range,range);
                    }
                }
                for(int i=0;i<nhidden;i++) {
                    hidden_offsets(i) = random_range(-range,range);
                }
                for(int i=0;i<noutput;i++) {
                    for(int j=0;j<nhidden;j++) {
                        weights_output_hidden(i,j) = random_range(-range,range);
                    }
                }
                for(int i=0;i<noutput;i++) {
                    output_offsets(i) = random_range(-range,range);
                }
            }
        }

        void dealloc_train() {
            error.dealloc();
            hidden_deltas.dealloc();
            output_deltas.dealloc();
            classes.clear();
            vectors.clear();
        }

        void forward() {
            bp_propagate_activations(input,ninput,hidden,nhidden,
                                     weights_hidden_input,hidden_offsets,
                                     sigmoid_inited);
            bp_propagate_activations(hidden,nhidden,output,noutput,
                                     weights_output_hidden,output_offsets,
                                     sigmoid_inited);
        }

        void backward(int cls) {
            int i;
            copy(error,output);
            error(cls) -= 1;
            for(i=0;i<noutput;i++) {
                float deriv = output(i)*(1.0-output(i));
                output_deltas(i) = -deriv*error(i);
            }
            bp_propagate_deltas(hidden_deltas,noutput,
                                hidden,output_deltas,nhidden,
                                weights_output_hidden);
        }

        void update() {
            bp_update_weights(output_offsets,output_deltas,noutput,
                              hidden,nhidden,weights_output_hidden,
                              learningrate);
            bp_update_weights(hidden_offsets,hidden_deltas,nhidden,
                              input,ninput,weights_hidden_input,
                              learningrate);
        }

    };
}

namespace ocropus {
    Classifier *make_BpnetClassifier() {
        using namespace iupr_bpnet;
        return new BpnetClassifier();
    }
    Classifier *make_BpnetClassifierDumpIntoFile(const char *path) {
        using namespace iupr_bpnet;
        return new BpnetClassifier(path);
    }
};
